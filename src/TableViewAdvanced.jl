module TableViewAdvanced

using ..TableView, WebIO, Observables, JSExpr

export  Table,
        table_scope, table_scope_id, table_data, table_options, table_prepare_options, table_user_data, set_table_user_data,
        JS_loader_node,
        tva_example
        

const EVENTS_DEBUG = false

"""
    mutable struct Table 

The main `Table` structure representing the data and scope of the table.
"""
mutable struct Table 
    _table_data                 # the data source - currently a DataFrame only
    _scope                      # the table WebIO scope
    _options                    # the options for th ag-grid
    _prepare_options            # options for the Table object
    _user_data                  # aditional data that will pass between the different events and call back function - can be anything the user choose,
                                # such as the front end window in the Blink case or the JS context that is needed to run JS functions.

    function Table(table_data)
        return new(table_data, nothing, nothing, nothing)
    end
end

table_scope(t::Table) = t._scope
table_scope_id(t::Table) = t._scope.id
table_data(t::Table) = t._table_data
table_options(t::Table) = t._options
table_prepare_options(t::Table) = t._prepare_options

table_user_data(t::Table) = t._user_data
set_table_user_data(t::Table, data) = t._user_data = data

function Base.show(io::IO, obj::Table) 
        # compact = get(io, :compact, false)
    
        println(io, obj._scope !== nothing ? "Scope is Initialized" : "Scope is nothing")
        Base.show(io, obj._table_data)
end


"""
    function prepare_table_setup_events!(table::Table)

Go over all the user's supplied events and register them.
This function is internal and should not be called directly.
"""
function prepare_table_setup_events!(table::Table)
    options = table_options(table)
    # scope = table_scope(table)

    prepare_options = options[:PrepareTableOptions]
    if (haskey(prepare_options, :events))
        for (event, func) in prepare_options[:events]
            prepare_table_setup_event!(string(event), table)
        end
    end
end

"""
    prepare_table_mutator!(options::Dict{Symbol, Any}, scope::WebIO.Scope)

Tegister a specific event by creating an observable if necessary and creating a message with certain parameters taken from the JS side of the grid.
The basic message contains the following parameters:
    row         - row number, starting at 1 for Julia
    col         - column name - the field property of the grid column (TODO: need to cdecide what to pass for calculated rows)
    oldValue    - this property exist in the cellValueChange event
    newValue    - this property exist in the cellValueChange event
    rowData     - a Dict object containing all the fields and their values in the specific row
    node        - additional information about the state of the grid row  - currently, just the indication if the row is selected.
                  this indication is important for the rowSelected event, which is triggered twice, for selecting and unselecting the previous row  
This function is internal and should not be called directly.
"""
function prepare_table_setup_event!(event, table::Table)
    options = table_options(table)
    scope = table_scope(table)

    prepare_options = options[:PrepareTableOptions]

    # table_data = table_data(table)
    
    func = get(prepare_options[:events], Symbol(event), nothing)
    if (func !== nothing)
        if (EVENTS_DEBUG)
            @info "Registering Grid Event [$event]"
        end
        obs = scope[event]
        on(obs) do msg
            func(msg=msg, table=table)
        end
    
        js_func = @js function (ev)
            if ($EVENTS_DEBUG)
                console.group("Grid Event [" + $event + "]");            
                console.log("Event Data: ")
                console.log(ev)
            end
            @var x = Dict()
            if ev.rowIndex !== undefined
                x["row"] = ev.rowIndex + 1
            end
            if ev.column !== undefined && ev.column.colDef !== undefined
                x["col"] = ev.column.colDef.field
            end
            if ev.oldValue !== undefined
                x["oldValue"] = ev.oldValue
            end
            if ev.newValue !== undefined
                x["newValue"] = ev.newValue
            end
            if ev.data !== undefined
                x["row_data"] = ev.data
            end
            if ev.node !== undefined
                x["node"] = Dict(
                    "selected" => ev.node.selected,
                )
            end
            $obs[] = x
            if ($EVENTS_DEBUG)
                console.groupEnd();
            end

            return
        end
        options[Symbol("on$event")] = js_func
    end
end


"""
    prepare_table_mutator!(options::Dict{Symbol, Any}, scope::WebIO.Scope)

This function is being called by the original `TableView.showtable` function. it allows us to change the grid options and
table scope before creating the JS grid object, This function is where we do most of our modifications over the original TableView process.    
This function is internal and should not be called directly.
"""
function prepare_table_mutator!(options::Dict{Symbol, Any}, scope::WebIO.Scope)
    #@info keys(options)

    # try to include java script from a local file
    import!(scope, joinpath(dirname(@__FILE__), "TableViewAdvanced.js")) 
    # pushfirst!(scope.imports, Asset(joinpath(dirname(@__FILE__), "TableViewAdvanced.js"))) 

    col_defs = options[:columnDefs] 
    prepare_options = options[:PrepareTableOptions]
    
    table = prepare_options[:Table]
    table._scope = scope
    table._options = options
    
    # table_data = table_data(table)
    columns_options = get(prepare_options, :columnDefs, Dict()) 

    options[:rowSelection] = "single"
    options[:suppressRowDeselection] = false
    
    options[:defaultColDef] = get(prepare_options, :defaultColDef, Dict())

    # disable sorting on all rows and remove the row id
    for c in col_defs
        # skip the internal row field
        if (c[:field] == "__row__")
            continue
        end

        # c[:sortable] = false
        # remove certain default definition that the original TableView added per field
        for key in [:sortable, :resizable, :headerTooltip, :editable]
            if (haskey(c, key))
                delete!(c, key)
            end
        end
        
        # hide the ID field - the GUID field that identify each row
        # if (c[:field] == "ID")
        #     c[:hide] = true
        #     @show c
        # end

        column_options = get(columns_options, Symbol(c[:field]), Dict())

        for (col_opt_key, col_opt_value) in column_options
            c[col_opt_key] = col_opt_value
        end

        # c[:headerName] = get(column_options, :Title, c[:headerName])
        # c[:headerTooltip] = get(column_options, :TitleTooltip, c[:headerTooltip])
        # c[:editable] = get(column_options, :Editable, true)
        # c[:resizable] = get(column_options, :Resizable, c[:resizable])
        # c[:sortable] = get(column_options, :Sortable, c[:sortable])

        editor = get(column_options, :CellEditor, nothing)
        renderer = get(column_options, :CellRenderer, nothing)
        if (editor == "ComboBox")
            c[:cellEditor] = "agSelectCellEditor"
            c[:cellEditorParams] = Dict( :values => get(column_options, :CellEditorParams, []))
        elseif (editor !== nothing)
            c[:cellEditor] = editor
        end

        if (renderer !== nothing)
            c[:cellRenderer] = renderer
        end

    end

    # register the user's grid events
    prepare_table_setup_events!(table)    
    # remove the prepare table information from the options Dict - was just used to pass the information to the mutator
    delete!(options, :PrepareTableOptions)

end


"""
    prepare_table(table_data, table_options::Dict{Symbol, Any})

Return a `Table` object that contains a reference to the table data and a scope for displaying the provided `table`.
This function is internal and should not be called directly.
"""
function prepare_table(table_data, table_options::Dict{Symbol, Any})
    # create a copy of the options and add the dataframe to pass to the mutator
    table_options = copy(table_options)
    # table_options[:TableData] = table_data

    # scope will be updated in the mutator function
    table = Table(table_data) 
    table._prepare_options = table_options
    table_options[:Table] = table

    # these are the options we are sending to the original table view package in order to handle the data our way in the option mutator
    options = Dict{Symbol, Any}(
        :PrepareTableOptions => table_options
    )

    TableView.showtable(
        table_data, 
        options = options,
        option_mutator! = prepare_table_mutator!, 
    )

    return table
end



"""
    Table(data, table_options::Dict{Symbol, Any})

Return a `Table` object that contains a reference to the table data and a scope for displaying the provided `table`.
"""
function Table(data, table_options::Dict{Symbol, Any})
    table = prepare_table(data, table_options)    
    return table
end


"""
    JS_loader_node(filenames...)

Return a `WebIO.Node` object that contains all the supplied files as children nodes. Recognized extentions files such
as '.js' and '.css' are contains in a :script and :style nodes respectivly.
"""
function JS_loader_node(filenames...)
    @info filenames
    nodes = []
    for filename in filenames
        ext = lowercase(splitext(filename)[2])
        @info ext
        data = read(filename)
        data = String(UInt8.(data))   # conver to a string from vector of bytes
        if (ext == ".js")
            push!(nodes, Node(:script, data))
        elseif (ext == ".css")
            push!(nodes, Node(:style, data))
        else
            push!(nodes, Node(:dome, data))
        end
    end
    
    return Node(:dom, nodes...)
end


function tva_example(example_name)
    if (splitext(example_name)[2] == "")
        example_name = "$(example_name).jl"
    end
    filename = abspath(joinpath(dirname(Base.find_package("TableView")), "..", "examples", example_name))
    return filename;
end


end # module TableViewAdvanced