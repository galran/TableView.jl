
module TableViewExample

using Blink, CSV, DataFrames, WebIO, CSSUtil, Interact
using TableView.TableViewAdvanced

println("Starting [$(splitext(basename(@__FILE__))[1])]")

#=======================================
load the data for this example
=======================================#
current_file_folder = dirname(@__FILE__)
csv = CSV.File(joinpath(current_file_folder, "Data", "Data01.csv"))
df = DataFrame(csv)
# convert all the column to type Any to make it easier to process any type of imput and replace all missing values with spaces
for col in names(df)
    df[!,Symbol(col)] = Vector{Any}(df[!,Symbol(col)])
    replace!(df[!, col], missing => "");
end


#=======================================
define table options
=======================================#
table_options = Dict{Symbol, Any}(
    :columnDefs => Dict(
        :ObjectID => Dict(
            :headerName => "Object ID",
            :headerTooltip => "A Unique name to identify this row",
        ),
        :Comment => Dict(
            :headerName => "Comment",
        ),
        :ObjectType => Dict(
            :headerName => "Object Type",
        ),
        :Position => Dict(
            :headerName => "Position(x,y,z,θx,θy,θz)",
        ),
        :RelativeTo => Dict(
            :headerName => "Relative To",
        ),
        :Material => Dict(
            :headerName => "Material",
        ),
        :Parameters => Dict(
            :headerName => "Parameters (radium, thinkness, conic, etc)",
        ),

    ),
    :defaultColDef => Dict(
        :editable => false,
        :sortable => true,
        :resizable => true,
    ),
)

table = TableViewAdvanced.Table(df, table_options)


#=======================================
Create Blink Window
=======================================#
window_defaults = Blink.@d(
    :title => "Grid Example 01", 
    :width=>1200, 
    :height=>800,
)
win = Window(window_defaults)

# set the window as the table's "user data"  so we can use it inside grid events to run JS code
set_table_user_data(table, win)

#=======================================
create some of the ui widgets
=======================================#
toggle_dev_tools_button = button("Toggle Dev Tools")
on(toggle_dev_tools_button) do val
    Blink.AtomShell.tools(win)
end

show_in_repl_button = button("Show Data in REPL")
on(show_in_repl_button) do val
    @info df
end

ui_widgets = hbox(
    toggle_dev_tools_button,
    Node(:span, attributes=Dict(:style => "width: 10px;")),     # add a small space between the two buttons
    show_in_repl_button,
)

#=======================================
create some of the ui widgets
=======================================#

ui = Node(:dom, 
    JS_loader_node(joinpath(dirname(@__FILE__), "examples.css")),                       # load the examples CSS file - not used in this example
    Node(:h1, "Grid Example 01"),
    Node(:h2, "In this example we create a read-only grid. We used the defaultColDef part of the options to indicate that :editable=false for all columns, unless a specific column override this option)."),
    Node(:h2, "We also show in this example how to change the header/caption of the presented columns in the grid."),
    Node(:hr),
    ui_widgets,
    Node(:hr),
    Node(:div, table_scope(table)),
)

body!(win, ui, async=false)
# Blink.AtomShell.opentools(win)

 
println("Ending [$(splitext(basename(@__FILE__))[1])]")
end # module TableViewExample 