
"""
    compute_mumu_bounds(    fixP,           fixT,
                            bulk_ref,       oxi,
                            oxide1_idx,     oxide2_idx,
                            oxide1_min,     oxide1_max,
                            oxide2_min,     oxide2_max,
                            dtb,            bufferType, solver,
                            verbose,        bufferN,    phase_selection,
                            cpx,            limOpx,     limOpxVal   )

    Pre-pass for a mu-mu (chemical potential) diagram: at fixed P,T and the
    reference bulk composition, runs 4 single-point minimizations — oxide1
    at its min/max content bound (oxide2 held at its reference value), then
    oxide2 at its min/max bound (oxide1 held at its reference value) — and
    reads off the resulting chemical potentials (`Gamma`) for the varied
    oxide from each. This determines the μ-axis bounds a mu-mu grid should
    span (μ generally moves non-monotonically-predictably with which bound
    is "min"/"max" content, so the two evaluated values are sorted into
    (mu_min, mu_max) rather than assumed to correspond directly to
    (content_min, content_max)).

    Self-contained (own single-thread `init_MAGEMin` instance) so it can run
    standalone from a "Compute μ bounds" UI action before any AMR mesh or
    the main multi-threaded `MAGEMin_data` bundle exists — mirrors
    `get_wat_sat_function`'s pre-pass pattern below.

    Returns `(mu1_bounds, mu2_bounds, statuses, ok)` where `statuses` is the
    4 `gmin_struct.status` values (0 = converged, 5 = not converged) in
    (oxide1_min, oxide1_max, oxide2_min, oxide2_max) order, and `ok` is
    `all(statuses .== 0)`.
"""
function compute_mumu_bounds(   fixP            :: Float64,
                                fixT            :: Float64,
                                bulk_ref        :: Vector{Float64},
                                oxi             :: Vector{String},
                                oxide1_idx      :: Int64,
                                oxide2_idx      :: Int64,
                                oxide1_min      :: Float64,
                                oxide1_max      :: Float64,
                                oxide2_min      :: Float64,
                                oxide2_max      :: Float64,
                                dtb             :: String,
                                bufferType      :: String,
                                solver          :: String,
                                verbose,
                                bufferN         :: Float64,
                                phase_selection,
                                cpx,            limOpx,     limOpxVal   )

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb, solver, cpx, limOpx, limOpxVal )

    gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                            verbose     = verbose,
                                            mbCpx       = mbCpx,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            buffer      = bufferType,
                                            solver      = sol    );

    sys_in  = "mol"

    function eval_gamma(content1, content2, target_idx)
        trial               = deepcopy(bulk_ref)
        trial[oxide1_idx]   = content1
        trial[oxide2_idx]   = content2
        gv2     = define_bulk_rock(gv, trial, oxi, sys_in, dtb)
        out     = deepcopy( point_wise_minimization(fixP, fixT, gv2, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
        return out.Gamma[target_idx], out.status
    end

    mu1_a, status_1a  = eval_gamma(oxide1_min, bulk_ref[oxide2_idx], oxide1_idx)
    mu1_b, status_1b  = eval_gamma(oxide1_max, bulk_ref[oxide2_idx], oxide1_idx)
    mu2_a, status_2a  = eval_gamma(bulk_ref[oxide1_idx], oxide2_min, oxide2_idx)
    mu2_b, status_2b  = eval_gamma(bulk_ref[oxide1_idx], oxide2_max, oxide2_idx)

    LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))

    mu1_bounds  = (min(mu1_a,mu1_b), max(mu1_a,mu1_b))
    mu2_bounds  = (min(mu2_a,mu2_b), max(mu2_a,mu2_b))
    statuses    = (status_1a, status_1b, status_2a, status_2b)
    ok          = all(statuses .== 0)

    return mu1_bounds, mu2_bounds, statuses, ok
end


"""
    get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                dtb,        bufferType, solver,
                                verbose,    bufferN,
                                cpx,        limOpx,     limOpxVal)

    Computes water-saturation at sub-solidus

"""
function get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                    dtb,        bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal, watsat_val)
   
    id_h2o      = findfirst(oxi .== "H2O")
    hydrated    = 1;
    watsat_val  = watsat_val/100.0

    if bulk_ini[id_h2o] == 0.0
        hydrated = 0;
    end

    liq = 1;
    if ~isnothing(phase_selection) && "liq" in phase_selection
        liq = 0;
    end

    if liq == 1 && hydrated == 1                                
        println("Computing water-saturation at sub-solidus. Make sure you provided enough water to oversaturate below solidus.")
        stp     = (Yrange[2] - Yrange[1])/31.0                        
        Prange  = Vector(Yrange[1]:stp:Yrange[2])

        # prepare flags
        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 

        # initialize single thread MAGEMin 

        gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                                verbose     = verbose,
                                                mbCpx       = mbCpx,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                buffer      = bufferType,
                                                solver      = sol    );

        sys_in      = "mol"
        gv          =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        Tmin        = 500.0;
        Tliq        = 2200.0;
        tolerance   = 1e-4;      

        Tsol        = zeros(Float64,length(Prange))
        SatSol      = zeros(Float64,length(Prange))

        @showprogress 1 "Computing sub-solidus water-saturating curve..." for i = 1:length(Prange)

            pressure    = Prange[i]
            out         = deepcopy( point_wise_minimization(pressure, Tliq, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
            n_max       = 64
            a           = Tmin
            b           = Tliq
            n           = 1
            conv        = 0
            n           = 0
            sign_a      = -1

            while n < n_max && conv == 0
                c       = (a+b)/2.0
                out     = deepcopy( point_wise_minimization(pressure, c, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

                if "liq" in out.ph
                    result = 1;
                else
                    result = -1;
                end

                sign_c  = sign(result)

                if abs(b-a) < tolerance
                    conv = 1
                else
                    if  sign_c == sign_a
                        a = c
                        sign_a = sign_c
                    else
                        b = c
                    end
                    
                end
                n += 1
            end

            Tsol[i]     = (a+b)/2.0
            out         = deepcopy( point_wise_minimization(pressure, (a+b)/2.0 + 0.01 , gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

            id_dry      = findall(out.oxides .!= "H2O")
            id_h2o      = findall(out.oxides .== "H2O")[1]

            tmp_bulk    = deepcopy(out.bulk)

            # extracting excess water
            if "H2O" in out.ph
                id = findfirst(out.ph .== "H2O")
                tmp_bulk .-= out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
            elseif "fl" in out.ph
                id = findfirst(out.ph .== "fl")
                tmp_bulk .-= out.SS_vec[id].Comp .* out.ph_frac[id]
            end            
            tmp_bulk ./= sum(tmp_bulk)              # normalize to 100%

            if watsat_val > 0.0
                tmp_bulk[id_h2o] += watsat_val/(1.0 - watsat_val)
                tmp_bulk ./= sum(tmp_bulk) 
            end

            tmp_bulk ./= sum(tmp_bulk[id_dry])      # normalize on anhydrous basis, to get water content
            SatSol[i]  = tmp_bulk[id_h2o]
            
        end

        # println("SatSol $SatSol")
        pChip_wat   = Interpolator(Prange, SatSol)
        pChip_T     = Interpolator(Prange, Tsol)
        LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))
    else
        println("To compute water-saturation at sub-solidus liq must be part of the solution phase model and the bulk composition must contain water")
        println("Phase diagram will be computed without water-saturation at sub-solidus...")
        pChip_wat, pChip_T = nothing, nothing
    end

    return pChip_wat, pChip_T
end


"""
    MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}})

    Transform MAGEMin output into a table

"""
function MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}},dtb)

    db_in     = retrieve_solution_phase_information(dtb)
    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))

    if typeof(out) == MAGEMin_C.gmin_struct{Float64, Int64}
        out = [out]
    end
    np      = length(out)

    table   = "# MAGEMin " * " $(out[1].MAGEMin_ver);" * datetoday * ", " * rightnow * "; using database " * AppData.db_inf.db_info * "\n"
    table   *=   "point[#] X[0.0-1.0] P[kbar] T[°C]" *" phase" * " mode[mol%]" * " mode[wt%]" * " log10(fO2)" * " log10(dQFM)" * " aH2O" * " aSiO2" * " aTiO2" *  " aAl2O3" *  " aMgO" *  " aFeO" * 
                " density[kg/m3]" * " volume[cm3/mol]" * " heatCapacity[kJ/K]" * " alpha[1/K]" * " Entropy[kJ/K]" * " Enthalpy[kJ/mol]" *
                " Vp[km/s]" * " Vs[km/s]" * " Vp_S[km/s]" * " Vs_S[km/s]" *" BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = out[k].n_PP
        table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * prt(out[k].fO2[1]) * prt(out[k].dQFM[1]) *prt(out[k].aH2O) *prt(out[k].aSiO2) *prt(out[k].aTiO2) *prt(out[k].aAl2O3) *prt(out[k].aMgO) *prt(out[k].aFeO) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].s_cp[1]) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
        prt(out[k].Vp) * prt(out[k].Vs) *prt(out[k].Vp_S) * prt(out[k].Vs_S) *prt(out[k].bulkMod) * prt(out[k].shearMod) *
        prt(out[k].bulk.*100.0) * prt(out[k].bulk_wt.*100.0) * "\n"
        for i=1:nss
            table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[i] * prt(out[k].ph_frac[i].*100.0) * prt(out[k].ph_frac_wt[i].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
            prt(out[k].SS_vec[i].rho) * prt(out[k].SS_vec[i].V) * prt(out[k].SS_vec[i].cp) * prt(out[k].SS_vec[i].alpha) * prt(out[k].SS_vec[i].entropy) * prt(out[k].SS_vec[i].enthalpy) *
            prt(out[k].SS_vec[i].Vp) * prt(out[k].SS_vec[i].Vs) * " -" * " -" *prt(out[k].SS_vec[i].bulkMod) * prt(out[k].SS_vec[i].shearMod) *
            prt(out[k].SS_vec[i].Comp.*100.0) * prt(out[k].SS_vec[i].Comp_wt.*100.0) * "\n"
        end

        if npp > 0
            for i=1:npp
                pos = i + nss
                table *= "$k" * prt(out[k].X[1]) * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[pos] * prt(out[k].ph_frac[pos].*100.0) * prt(out[k].ph_frac_wt[pos].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
                prt(out[k].PP_vec[i].rho) * prt(out[k].PP_vec[i].V) * prt(out[k].PP_vec[i].cp) * prt(out[k].PP_vec[i].alpha) * prt(out[k].PP_vec[i].entropy) * prt(out[k].PP_vec[i].enthalpy) *
                prt(out[k].PP_vec[i].Vp) * prt(out[k].PP_vec[i].Vs) * " -" * " -" * prt(out[k].PP_vec[i].bulkMod) * prt(out[k].PP_vec[i].shearMod) *
                prt(out[k].PP_vec[i].Comp.*100.0) * prt(out[k].PP_vec[i].Comp_wt.*100.0) * "\n"
            end
        end

    end


    return table
end


# find_dominant_em_ids
function find_dominant_em_ids(  SS_vec )
    n_ph    = length(SS_vec)
    ids     = ()
    for i=1:n_ph
        f    = SS_vec[i].emFrac
        ids  = (ids..., findfirst(f .== maximum(f)))
    end
    
    return ids
end

function get_dominant_em(   ph,
                            n_SS,
                            SS_vec)
    n_ph  = length(ph)
    ph_em = Vector{String}(undef,n_ph)
    for i=1:n_SS
        f = SS_vec[i].emFrac
        id = findall(f .== maximum(f))[1]
        em = SS_vec[i].emNames[id]
        ph_em[i] = ph[i]*":"*em
    end
    for i=n_SS+1:n_ph
        ph_em[i] = ph[i]
    end

    return ph_em
end

function get_data_thread( MAGEMin_db :: MAGEMin_Data )

    id          = Threads.threadid()
    gv          = MAGEMin_db.gv[id]
    z_b         = MAGEMin_db.z_b[id]
    DB          = MAGEMin_db.DB[id]
    splx_data   = MAGEMin_db.splx_data[id]

   return (gv, z_b, DB, splx_data)
end

"""
    multi_point_mumu(     target_mu1,     target_mu2,
                        oxide1_idx,     oxide2_idx,
                        bulk_ref,       oxi,
                        fixP,           fixT,       dtb,
                        MAGEMin_data;
                        bufferN, phase_selection, tol )

    For a mu-mu (chemical potential) diagram: given `n = length(target_mu1)`
    target (μ1,μ2) grid points, compute — independently per point, in
    parallel — the equilibrium at each target via MAGEMin_C's native
    chemical-potential-fixing mechanism (`mu_fix_idx`/`mu_fix_val`): one
    `point_wise_minimization` call per point with
    `mu_fix_val=[target_mu1[i], target_mu2[i]]`, no search loop. Requires
    `MAGEMin_data` to have been built with
    `mu_fix_idx=[oxi[oxide1_idx],oxi[oxide2_idx]]` at `Initialize_MAGEMin`
    time (see `refine_MAGEMin`'s "mumu" branch and
    `compute_new_phaseDiagram`/`refine_phaseDiagram`, which build it this
    way whenever `diagType=="mumu"`).

    The trial bulk composition is `bulk_ref` with both mu-mu oxides
    unconditionally overridden to `100.0` (mol%, pre-normalization) — the
    bulk-rock table's own entries for those two oxides are irrelevant here
    (locked/greyed in the UI) and never read. MAGEMin_C's docs for
    `mu_fix_val` require each fixed oxide's bulk content to be set
    "generously in excess" of what its target implies, or the underlying
    fictive-phase mechanism may not reliably activate; `100.0` is used
    unconditionally for both oxides so this always holds regardless of P,T
    or the rest of the bulk composition, without needing user input.
    MAGEMin_C explicitly does not itself verify the target was hit, so this
    still checks `out.Gamma` against `(target_mu1[i],target_mu2[i])` before
    reporting a point converged.

    Mirrors `multi_point_minimization`'s own `@threads :static` outer loop
    over grid points and per-thread buffer pattern (`get_data_thread`) —
    NOT a modification of `multi_point_minimization` itself.

    Returns `(results, status)`: `results` is a `Vector{gmin_struct}` (for
    direct storage into `Out_XY`/`Hash_XY`/`n_phase_XY` like any other
    diagram type), `status` is `0` (both targets hit within `tol`) or `5`
    (not hit — e.g. a target outside what any real phase in the database
    can support at this P,T) per point, same convention as
    `gmin_struct.status`.
"""
function multi_point_mumu(     target_mu1      :: Vector{Float64},
                                target_mu2      :: Vector{Float64},
                                oxide1_idx      :: Int64,
                                oxide2_idx      :: Int64,
                                bulk_ref        :: Vector{Float64},
                                oxi             :: Vector{String},
                                fixP            :: Float64,
                                fixT            :: Float64,
                                dtb             :: String,
                                MAGEMin_data    :: MAGEMin_Data;
                                bufferN         :: Float64 = 0.0,
                                phase_selection = nothing,
                                tol             :: Float64 = 1e-3    )

    n           = length(target_mu1)
    results     = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, n)
    status      = Vector{Int64}(undef, n)
    sys_in      = "mol"

    trial_seed              = deepcopy(bulk_ref)
    trial_seed[oxide1_idx]  = 100.0
    trial_seed[oxide2_idx]  = 100.0

    count = 0

    @showprogress desc="Computing $n points..." @threads :static for i in eachindex(target_mu1)

        gv, z_b, DB, splx_data = get_data_thread(MAGEMin_data)

        gv2 = define_bulk_rock(gv, trial_seed, oxi, sys_in, dtb)
        out = deepcopy( point_wise_minimization(fixP, fixT, gv2, z_b, DB, splx_data, sys_in;
                                                    buffer_n=bufferN, rm_list=phase_selection, name_solvus=true,
                                                    mu_fix_val=[target_mu1[i], target_mu2[i]]    ) )

        conv        = abs(out.Gamma[oxide1_idx] - target_mu1[i]) < tol &&
                      abs(out.Gamma[oxide2_idx] - target_mu2[i]) < tol

        results[i]  = out
        status[i]   = conv ? 0 : 5

        count += 1
        update_progress(count, n, time())
    end

    return results, status
end

function refine_MAGEMin(dtb,data,
                        MAGEMin_data    :: MAGEMin_Data, 
                        custW           :: Bool,
                        diagType        :: String,
                        PTpath,
                        phase_selection :: Union{Nothing,Vector{Int64}},
                        fixT            :: Float64,
                        fixP            :: Float64,
                        e1_liq          :: Float64,
                        e2_liq          :: Float64,
                        e1_remain_wat       :: Float64,
                        e2_remain_wat       :: Float64,
                        e1_remain       :: Float64,
                        e2_remain       :: Float64,
                        oxi             :: Vector{String},
                        bulk_L          :: Vector{Float64},
                        bulk_R          :: Vector{Float64},
                        bufferType      :: String,
                        bufferN1        :: Float64,
                        bufferN2        :: Float64,
                        scp             :: Int64,
                        boost           :: Bool,
                        refType         :: String,
                        pChip_wat       ,
                        pChip_T         ,
                        seismic_cor     :: Bool,
                        aspect_ratio    :: Float64,
                        seismic_water   :: Int64,
                        shallow_cor     :: Bool,
                        fluid_as_melt   :: Bool,
                        anelastic_correction :: Bool;
                        mumu_oxide1_idx     :: Int64                   = 0,
                        mumu_oxide2_idx     :: Int64                   = 0    )
    global Out_XY, addedRefinementLvl;

    #= First we create a structure to store the data in memory =#
    if custW == true
        if !isempty(AppData.customWs)
            df = AppData.customWs
            n_entries = size(df,1)
            new_Ws = Vector{MAGEMin_C.W_data{Float64,Int64}}(undef, n_entries)

            for i=1:size(df,1)
                dtb     = df[i, :dtb]
                ss_id   = df[i, :id]
                n_Ws    = df[i, :n_Ws]
                Ws      = split(df[i, :Ws], ";")
                Ws      = parse.(Float64, Ws)
                Ws      = reshape(Ws, n_Ws, 3)
                
                new_Ws[i] = MAGEMin_C.W_data(dtb, ss_id, n_Ws, Ws)   

                # println("new_Ws: $(new_Ws)")
            end
        else
            new_Ws = nothing
        end
    else
        new_Ws = nothing
    end

    if isempty(data.split_cell_list)
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.points))
        n_new_points    = length(data.points)
        npoints         = data.points
    else
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.npoints))
        n_new_points    = length(data.npoints)
        npoints         = data.npoints
    end

    for i in 1:Threads.maxthreadid()
        # copy bufferType's bytes into gv.buffer's existing (C-malloc'd, 10-byte)
        # buffer in place, rather than repointing gv.buffer at bufferType's own
        # memory - the latter left gv.buffer aliasing Julia-GC-owned memory
        # (a Julia String is not something C should ever free()), which caused
        # a SIGABRT when MAGEMin's FreeDatabases tried to free(gv.buffer)
        n = min(ncodeunits(bufferType), 9)
        unsafe_copyto!(MAGEMin_data.gv[i].buffer, Ptr{Cchar}(pointer(bufferType)), n)
        unsafe_store!(MAGEMin_data.gv[i].buffer, Cchar(0), n+1)
    end

    if n_new_points > 0
        Tvec = zeros(Float64,n_new_points);
        Pvec = zeros(Float64,n_new_points);
        Xvec = Vector{Vector{Float64}}(undef,n_new_points);
        Bvec = zeros(Float64,n_new_points);

        if !isempty(data.split_cell_list) && boost == true
            Gvec = Vector{Vector{LibMAGEMin.mSS_data}}(undef,n_new_points);
            Ivec = Vector{Bool}(undef,n_new_points) .= true;
        else
            Ivec = false
            Gvec = nothing;
        end

        if diagType == "mumu"

            target_mu1 = zeros(Float64,n_new_points)
            target_mu2 = zeros(Float64,n_new_points)
            for i = 1:n_new_points
                target_mu1[i] = npoints[i][1]
                target_mu2[i] = npoints[i][2]
            end

            Out_XY_new, mumu_status = multi_point_mumu(
                                            target_mu1,     target_mu2,
                                            mumu_oxide1_idx, mumu_oxide2_idx,
                                            bulk_L,         oxi,
                                            fixP,           fixT,           dtb,
                                            MAGEMin_data;
                                            bufferN         = bufferN1,
                                            phase_selection = phase_selection    )

            n_failed = count(==(5), mumu_status)
            if n_failed > 0
                println("Warning: $n_failed / $n_new_points mu-mu grid point(s) did not converge (status=5) — check your oxide content bounds.")
            end

        elseif diagType != "tt"
            if diagType == "tx"

                for i = 1:n_new_points
                    Pvec[i] = fixP;
                    Tvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "px"

                for i = 1:n_new_points
                    Tvec[i] = fixT;
                    Pvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "pt"

                if "H2O" in oxi
                    id_h2o      = findfirst(oxi .== "H2O")
                    id_dry      = findall(oxi .!= "H2O")
                end

                for i = 1:n_new_points
                    Tvec[i] = npoints[i][1];
                    Pvec[i] = npoints[i][2];
                    Bvec[i] = bufferN1;
                    
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end

                    # here we check if the water need to be saturated at sub-solidus
                    if ~isnothing(pChip_wat)
                        TsatSol     = pChip_T(Pvec[i])
                        waterSat    = pChip_wat(Pvec[i])

                        if Tvec[i] > TsatSol        # if we are above the solidus then we use the water content from the sub-solidus curve
                            tmp_bulk              = deepcopy(bulk_L)
                            tmp_bulk            ./= sum(tmp_bulk[id_dry])
                            tmp_bulk[id_h2o]      = waterSat
                            tmp_bulk            ./= sum(tmp_bulk)

                            if !isempty(data.ncorners) && boost == true # Here we roughly check if the bulk composition is feasible with respect to initial guess
                                check_bulk = vcat([Out_XY[data.npoints_ig[i][j]].bulk[id_h2o] for j=1:length(data.npoints_ig[i])]...)
                                if tmp_bulk[id_h2o] > maximum(check_bulk) || tmp_bulk[id_h2o] < minimum(check_bulk)
                                    Ivec[i] = false
                                end
                            end   

                            Xvec[i]               = tmp_bulk
                        else
                            Xvec[i] = bulk_L;
                        end
                    else
                        Xvec[i] = bulk_L;
                    end
                end
            elseif diagType == "ptx"

                ptx_data    = copy(PTpath)
                np          = length(ptx_data)
                Pres        = zeros(Float64,np)
                Temp        = zeros(Float64,np)
                x           = zeros(Float64,np)
                for i=1:np
                    Pres[i] = to_kbar_pressure(ptx_data[i][Symbol("col-1")])
                    Temp[i] = ptx_data[i][Symbol("col-2")]
                    x[i]    = (i-1)*(1.0/(np-1))
                end
                pChipInterp_P = Interpolator(x, Pres)
                pChipInterp_T = Interpolator(x, Temp)

                for i = 1:n_new_points
                    Tvec[i] = pChipInterp_T(npoints[i][2]); 
                    Pvec[i] = pChipInterp_P(npoints[i][2]);
                    Xvec[i] = bulk_L*(  1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true

                        n_ph = [ length(Out_XY[data.npoints_ig[i][j]].ph) for j=1:length(data.npoints_ig[i])]
                        ids  = sortperm(n_ph, rev=true)

                        tmp = [Out_XY[data.npoints_ig[i][ids[j]]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            end
            if diagType == "pt" && dtb != "sb11" && dtb != "sb21"  && dtb != "sb24" && dtb != "rMELTS" && dtb != "pMELTS" && isnothing(pChip_wat) == true
                fixed_bulk = true
            else
                fixed_bulk = false
            end
            Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                        X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp,
                                                        rm_list=phase_selection, name_solvus=true, fixed_bulk=fixed_bulk, iguess=Ivec, callback_fn = update_progress, W=new_Ws,
                                                        seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction);
        else
            # if TT diagram does not exist, compute it
            id_h2o = findfirst(oxi .== "H2O") # check if H2O is in the oxides
            if isempty(data.split_cell_list)    
                n           = Int64(sqrt(n_new_points))
                Out_col_1   = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n)
                start_bulk  = deepcopy(bulk_L)
                for i=1:n
                    out     = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                            X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp,
                                                            rm_list=phase_selection, name_solvus=true,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)
                    
                    if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                        if "fl" in out.ph
                            id               = findfirst(out.ph .== "fl")
                            start_bulk      .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                            start_bulk     .+= e1_remain_wat .* out.SS_vec[id].Comp;
                        end
                        if "H2O" in out.ph
                            id               = findfirst(out.ph .== "H2O")
                            start_bulk      .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                            start_bulk[id_h2o]  += e1_remain_wat;
                        end
                        if "liq" in out.ph
                            id = findfirst(out.ph .== "liq")

                            if  out.ph_frac_vol[id] > e1_liq/100.0
                                ratio        = (out.ph_frac_vol[id] - e1_remain/100.0)/out.ph_frac_vol[id]
                                start_bulk  .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                            end
                        end
                        start_bulk ./= sum(start_bulk)
        
                        out         = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                                    X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp,
                                                                    rm_list=phase_selection, name_solvus=true, W=new_Ws,
                                                                    seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)
            
                        Out_col_1[i] = deepcopy(out)
                        Out_col_1[i].X .= npoints[i][2]
                    else
                        Out_col_1[i] = deepcopy(out)
                        Out_col_1[i].X .= npoints[i][2]
                    end
                    
                end

                Out_rows    = Vector{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}}(undef, n);
                progr       = Progress(n, desc="Computing $n Polymetamorphic paths...") # progress meter
                @threads :static for i=1:n

                    Out_PT      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, n)
                    P_          = fixP
                    T_          = collect(range(data.Xrange[1], stop=data.Xrange[2], length=n))
                    bulk_       = deepcopy(Out_col_1[i].bulk)
                    X           = Out_col_1[i].X[1]

                    gv, z_b, DB, splx_data = get_data_thread(MAGEMin_data)
                    gv          = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                    for j=1:n 

                        out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                            buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)

                        if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                            if "fl" in out.ph
                                id              = findfirst(out.ph .== "fl")
                                bulk_          .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                                bulk_           .+= e2_remain_wat .* out.SS_vec[id].Comp;
                            end
                            if "H2O" in out.ph
                                id              = findfirst(out.ph .== "H2O")
                                bulk_          .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                                bulk_[id_h2o]  += e2_remain_wat;
                            end
                            if "liq" in out.ph
                                id = findfirst(out.ph .== "liq")
                                if  out.ph_frac_vol[id] > e2_liq/100.0
                                    ratio        = (out.ph_frac_vol[id] - e2_remain/100.0)/out.ph_frac_vol[id]
                                    bulk_       .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                                end
                            end
                            gv      = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                            out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                                buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws,
                                                                seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)

                            Out_PT[j] = deepcopy(out)
                            Out_PT[j].X .= X
                        else
                            Out_PT[j] = deepcopy(out)
                            Out_PT[j].X .= X
                        end
                    end
                    Out_rows[i] = Out_PT
                    next!(progr)
                end
                finish!(progr)

                for i=1:n
                    for j=1:n
                        Out_XY_new[(i-1)*n+j] = Out_rows[j][i]
                    end
                end

            else #refinement of the TT diagram
                for i = 1:n_new_points
                    tmp     = [Out_XY[data.npoints_ig[i][j]].X[1] for j=1:length(data.npoints_ig[i])]

                    Tvec[i] = npoints[i][1];
                    Pvec[i] = fixP;
                    Bvec[i] = bufferN1;

                    tmp_bulk = zeros(length(oxi))
                    for j=1:length(data.ncorners[i])
                        tmp_bulk .+= Out_XY[data.ncorners[i][j]].bulk
                    end
                    tmp_bulk  ./= Float64(length(data.ncorners[i]))
                    Xvec[i]     = tmp_bulk

                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end

                Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                            X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp,
                                                            rm_list=phase_selection, name_solvus=true, iguess=boost, callback_fn = update_progress, W=new_Ws,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction);

                for i=1:n_new_points
                    Out_XY_new[i].X .= data.npoints[i][2]  
                end
                
            end
        end
    else
        println("There is no new point to compute...")
    end
    Out_XY      = vcat(Out_XY, Out_XY_new)

    # Compute hash for all points
    n_points    = length(Out_XY)
    Hash_XY     = Vector{UInt64}(undef,n_points)
    n_phase_XY  = Vector{Int64}(undef,n_points)

    if refType == "ph"
        for i=1:n_points
            Hash_XY[i]      = hash(sort(Out_XY[i].ph))
            n_phase_XY[i]   = length(Out_XY[i].ph)
        end
    elseif refType == "em"
        for i=1:n_points
            ph_em = get_dominant_em(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)

            Hash_XY[i]      = hash(sort(ph_em))
            n_phase_XY[i]   = length(ph_em)
        end
    end

    if diagType == "tx" || diagType == "px" || diagType == "ptx"
        for i=1:n_points
            Out_XY[i].X .= data.points[i][1]
        end
    end

    return Out_XY, Hash_XY, n_phase_XY  
end

