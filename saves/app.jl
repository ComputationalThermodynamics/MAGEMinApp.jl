# module App

using GenieFramework
@genietools

@app begin
    @out tab = "home"
    @out msg1 = "Tab 1 😀"
    @out msg2 = "Tab 2 😀"
    @out msg3 = "Tab 3 😀"
end

@page("/", "tabs.html")

Server.up()