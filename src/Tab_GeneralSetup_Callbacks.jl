#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

function Tab_GeneralSetup_Callbacks(app)

    # apply a user-supplied output directory; falls back to the previous
    # value (kept in output_dir[1]) if the path can't be created
    callback!(
        app,
        Output("state-directory2",     "value"),
        Output("state-directory-2",    "value"),
        Output("state-directory-2-te", "value"),
        Output("output-dir-feedback",  "children"),
        Input("apply-output-dir-button", "n_clicks"),
        State("state-directory2",      "value"),

        prevent_initial_call=true,
    ) do n_clicks, path

        global output_dir

        path = strip(path)

        if isempty(path)
            return output_dir[1], "Figure directory: $(output_dir[1])", "Figure directory: $(output_dir[1])", "Path cannot be empty - keeping previous directory."
        end

        path = endswith(path, "/") ? path : path * "/"

        try
            isdir(path) || mkpath(path)
            output_dir[1] = path
            return path, "Figure directory: $(path)", "Figure directory: $(path)", "Output directory set to $(path)"
        catch
            return output_dir[1], "Figure directory: $(output_dir[1])", "Figure directory: $(output_dir[1])", "Could not use this path - keeping previous directory."
        end
    end;

    return app
end
