
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
grid event handlers
=======================================#
function OnCellValueChanged(; msg, table::Table, kwargs...)
    win = table_user_data(table)
    data = table_data(table)    # assuming a data frame

    # update the back-end data structure
    row = msg["row"]
    col = msg["col"]
    @info "Cell Change: $row, $col -> [$(msg["newValue"])]"     # debug message
    data[row, col] = msg["newValue"] 
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
            :cellEditor => "agLargeTextCellEditor",
        ),
        :ObjectType => Dict(
            :headerName => "Object Type",
            :cellEditor => "agSelectCellEditor",
            :cellEditorParams => Dict(
                values => ["SOURCE", "Spherical Lens", "STOP", "DETECTOR"],
            ),
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
        :editable => true,
        :sortable => true,
        :resizable => true,
    ),
    :events => Dict(
        :CellValueChanged => OnCellValueChanged,
    )
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

checkbox_test = checkbox(label="""Hide the "Position" Column""")
on(checkbox_test) do val
    global table
    win = table_user_data(table)

    @js_ win begin
        x = [
            Dict(:field => "Position", :hide => $(val)),
        ]
        TVJS_UpdateColumns($(table_scope_id(table)), x)
    end
end

ui_widgets = hbox(
    toggle_dev_tools_button,
    Node(:span, attributes=Dict(:style => "width: 10px;")),
    show_in_repl_button,
    checkbox_test, 
)

#=======================================
create some of the ui widgets
=======================================#

ui = Node(:dom, 
    JS_loader_node(joinpath(dirname(@__FILE__), "examples.css")), 
    Node(:h1, "Grid Example 02"),
    Node(:h2, "Some of the features we show in this example:."),
    Node(:ul,
        Node(:li, "Large text editor for editing the Comment field"),
        Node(:li, "ComboBox style editor for the ObjectType field"),
        Node(:li, "Hide/Show column toggle that show how to update columns properties in run-time."),
        Node(:li, "CellValueChanged - a grid event that shows how to update the back-end data structure (a DataFRame in this case)"),
    ),
    Node(:hr),
    ui_widgets,
    Node(:hr),
    Node(:div, table_scope(table)),
)

body!(win, ui, async=false)
 
println("Ending [$(splitext(basename(@__FILE__))[1])]")
end # module TableViewExample 