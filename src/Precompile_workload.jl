#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMinApp
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

function split_dash_output(output::AbstractString)
    parts = startswith(output, "..") ? split(output[3:end-2], "...", keepempty = false) : [output]
    return [Tuple(String.(rsplit(p, ".", limit = 2))) for p in parts], startswith(output, "..")
end

function first_tab_id(children)
    tabs = children isa AbstractVector ? children : [children]
    for (i, tab) in enumerate(tabs)
        tab isa AbstractDict && haskey(tab, :props) || continue
        return String(get(tab[:props], :tab_id, "tab-$(i - 1)"))
    end
    return "tab-0"
end

function collect_layout_props!(props::Dict{Tuple{String,String},Any}, mounted::Vector{Tuple{String,String}}, node)
    if node isa AbstractDict
        if haskey(node, :props) && haskey(node, :type)
            p  = node[:props]
            id = get(p, :id, nothing)
            if id isa AbstractString
                for (k, v) in pairs(p)
                    k == :children || (props[(String(id), String(k))] = v)
                end
                if node[:type] == "Store" && haskey(p, :data) && isnothing(p[:data])
                    push!(mounted, (String(id), "data"))
                elseif node[:type] == "Tabs" && get(node, :namespace, "") == "dash_bootstrap_components" && !haskey(p, :active_tab)
                    props[(String(id), "active_tab")] = first_tab_id(get(p, :children, []))
                    push!(mounted, (String(id), "active_tab"))
                end
            end
            collect_layout_props!(props, mounted, get(p, :children, nothing))
        end
    elseif node isa AbstractVector
        for child in node
            collect_layout_props!(props, mounted, child)
        end
    end
    return props
end

function dash_prop_list(props, deps)
    return [haskey(props, (String(d[:id]), String(d[:property]))) ?
                Dict("id" => d[:id], "property" => d[:property], "value" => props[(String(d[:id]), String(d[:property]))]) :
                Dict("id" => d[:id], "property" => d[:property]) for d in deps]
end

function replay_page_load(app; skip_inputs = ("version-check-interval",), max_calls = 400)
    handler = Dash.make_handler(app)
    gzip    = ["Accept-Encoding" => "gzip"]
    for path in ("/", "/_dash-layout", "/_dash-dependencies")
        handler(HTTP.Request("GET", path, gzip))
    end
    layout  = JSON3.read(String(handler(HTTP.Request("GET", "/_dash-layout")).body))
    deps    = JSON3.read(String(handler(HTTP.Request("GET", "/_dash-dependencies")).body))
    mounted = Tuple{String,String}[]
    props   = collect_layout_props!(Dict{Tuple{String,String},Any}(), mounted, layout)

    server_deps = [d for d in deps if isnothing(d[:clientside_function]) &&
                                      !any(i -> i[:id] in skip_inputs, d[:inputs])]
    by_input    = Dict{Tuple{String,String},Vector{Int}}()
    for (k, d) in enumerate(server_deps), i in d[:inputs]
        push!(get!(by_input, (String(i[:id]), String(i[:property])), Int[]), k)
    end

    queue = [(k, String[]) for (k, d) in enumerate(server_deps) if !d[:prevent_initial_call]]
    for key in mounted, k in get(by_input, key, Int[])
        push!(queue, (k, ["$(key[1]).$(key[2])"]))
    end
    fired = Set{Int}()
    while !isempty(queue) && length(fired) < max_calls
        k, changed = popfirst!(queue)
        k in fired && continue
        push!(fired, k)
        d             = server_deps[k]
        outs, multi   = split_dash_output(d[:output])
        out_list      = [Dict("id" => id, "property" => pr) for (id, pr) in outs]
        payload       = Dict{String,Any}("output"         => d[:output],
                                         "outputs"        => multi ? out_list : out_list[1],
                                         "inputs"         => dash_prop_list(props, d[:inputs]),
                                         "changedPropIds" => changed)
        isempty(d[:state]) || (payload["state"] = dash_prop_list(props, d[:state]))
        response = handler(HTTP.Request("POST", "/_dash-update-component",
                                        ["Content-Type" => "application/json"], JSON3.write(payload)))
        response.status == 200 || continue
        for (id, upd) in pairs(JSON3.read(String(response.body))[:response]), (pr, val) in pairs(upd)
            key        = (String(id), String(pr))
            props[key] = val
            for k2 in get(by_input, key, Int[])
                k2 in fired || push!(queue, (k2, ["$(key[1]).$(key[2])"]))
            end
        end
    end
    return [server_deps[k][:output] for k in fired]
end

function precompile_page_load()
    saved   = [(v, deepcopy(v)) for v in (values(AppData)..., use_warr_names, use_GPa) if v isa Vector]
    cur_dir = pwd()
    cd(pkg_dir)
    try
        redirect_stdout(devnull) do
            Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
                replay_page_load(build_app(verbose = false))
            end
        end
    catch err
        @warn "MAGEMinApp: page-load precompilation skipped" exception = err
    finally
        cd(cur_dir)
        for (v, s) in saved
            copy!(v, s)
        end
    end
end
