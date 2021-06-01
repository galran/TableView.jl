
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
grid utility functions
=======================================#
function RefreshCells(; table::Table, kwargs...)
    scope_id = table_scope_id(table)

    @js_ win begin
        TVJS_RefreshCells($(scope_id))
    end
end

function ConvertJSFunctions(; table::Table, kwargs...)
    scope_id = table_scope_id(table)

    @js_ win begin
        TVJS_ConvertJSFunctions($(scope_id))
    end
end


function UpdateColumnsHeaders(; table::Table, kwargs...)
    win = table_user_data(table)


    @js_ win begin
        @var gridOptions = TVJS_GridOptions($(table_scope_id(table)))
        @var rows = gridOptions.api.getSelectedRows();

        @var ObjectTypes = Dict(
            "SOURCE" => [
                Dict(:field => "RelativeTo", :headerName => "SOURCE Relative To"),      
                Dict(:field => "Parameters", :headerName => "SOURCE Parameters"),
            ],
            "Spherical Lens" => [
                Dict(:field => "RelativeTo", :headerName => "Spherical Lens Relative To"),      
                Dict(:field => "Parameters", :headerName => "Spherical Lens Parameters"),
            ],
            "DETECTOR" => [
                Dict(:field => "RelativeTo", :headerName => "DETECTOR Relative To"),      
                Dict(:field => "Parameters", :headerName => "DETECTOR Parameters"),
            ],
            "STOP" => [
                Dict(:field => "RelativeTo", :headerName => "N/A"),      
                Dict(:field => "Parameters", :headerName => "N/A"),
            ],
        )
    
        # defualt value to the column's headers - in case no row is selected
        @var x = [                                              
            Dict(:field => "RelativeTo", :headerName => "??"),      
            Dict(:field => "Parameters", :headerName => "??"),
        ]
        if (rows.length === 1)      # if there is exactly one selected rows then we update the column names accoording to the value of that row
            row = rows[0]

            if (ObjectTypes.hasOwnProperty(row.ObjectType))
                x = ObjectTypes[row.ObjectType]
            end
        end
        # update the columns - can be updated with any property of the column, including the cell editor, style etc.
        TVJS_UpdateColumns($(table_scope_id(table)), x)
    end
end


#=======================================
grid event handlers
=======================================#
function OnGridReady(; msg, table::Table, kwargs...)
    scope_id = table_scope_id(table)
    win = table_user_data(table)

    ConvertJSFunctions(table=table)
    UpdateColumnsHeaders(table=table)
    RefreshCells(table=table)
end

function OnCellValueChanged(; msg, table::Table, kwargs...)
    win = table_user_data(table)
    data = table_data(table)    # assuming a data frame

    # update the back-end data structure
    row = msg["row"]
    col = msg["col"]
    # @info "Cell Change: $row, $col -> [$(msg["newValue"])]"     # debug message
    data[row, col] = msg["newValue"] 

    # update the headers in case ObjectType is updated
    if (msg["col"] == "ObjectType")
        UpdateColumnsHeaders(table=table)
    end

end

function OnSelectionChanged(; msg, table::Table, kwargs...)
    UpdateColumnsHeaders(table=table)
end

function OnCellFocused(; msg, table::Table, kwargs...)
    scope_id = table_scope_id(table)
    win = table_user_data(table)

    js_row_index = msg["row"] - 1
    # @show js_row_index
    @js_ win begin
        @var gridOptions = TVJS_GridOptions($(scope_id))
        TVJS_SelectRow(gridOptions, $js_row_index)
    end
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
            :cellClassRules => Dict(
                "example-style-green" => "x === 'SOURCE'",          # these are setting the class of the cell which draw its style from the CSS
                "example-style-amber" => "x === 'STOP'",
                "example-style-red" => "x === 'Spherical Lens'",
            ),
        ),
        :Position => Dict(
            :headerName => "Position(x,y,z,θx,θy,θz)",
            :cellRenderer_jsfunc => "PositionCellRenderer",
            :cellEditor_jsfunc => "PositionPopupCellEditor",
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
        :GridReady => OnGridReady,
        :CellValueChanged => OnCellValueChanged,
        :CellFocused => OnCellFocused,
        :SelectionChanged => OnSelectionChanged,
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

hide_column_checkbox = checkbox(label="""Hide the "Position" Column""")
on(hide_column_checkbox) do val
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
    hide_column_checkbox, 
)

#=======================================
create some of the ui widgets
=======================================#

ui = Node(:dom, 
    JS_loader_node(joinpath(dirname(@__FILE__), "examples.css"), joinpath(dirname(@__FILE__), "examples.js")), 
    Node(:h1, "Grid Example 03"),
    Node(:h2, "Some of the features we show in this example:."),
    Node(:ul,
        Node(:li, "Dynamic Cell Style (ObjectType Column)"),
        Node(:li, "Dynamic Column Header Change depending on row the selected row values (RelativeTo and Paramteres headers are changing depending on the value in ObjectType)"),
        Node(:li, "Modify the grid default beheviour of not allowing the focused cell be outside a the selected row - selecting the row in the OnCellFocused event handler"),
        Node(:li, "Show how to create a custom cell renderer and cell editor for the position column."),
    ),
    Node(:hr),
    ui_widgets,
    Node(:hr),
    Node(:div, table_scope(table)),
)

body!(win, ui, async=false)
 
println("Ending [$(splitext(basename(@__FILE__))[1])]")
end # module TableViewExample 