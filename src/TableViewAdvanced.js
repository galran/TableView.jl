
// Select the row at index row_index
function TVJS_SelectRow(gridOptions, row_index) {
    gridOptions.api.forEachNode(node => {
        if (node.rowIndex === row_index) {
            node.setSelected(true, true);
        }
    });    
}

// update the columns - currently support only updates by field name (not sure about how to support calculated rows)
function TVJS_UpdateColumns(scope_id, list_of_deltas) {
    var gridOptions = TVJS_GridOptions(scope_id)
    //var defs = RGDeepCopyFunction(gridOptions.columnDefs)
    var defs = gridOptions.columnDefs

    defs.forEach(function (defs_item, defs_index) {
        //console.log(defs_item, defs_index);
        list_of_deltas.forEach(function (delta_item, delta_index) {
            if (defs_item.field == delta_item.field) {
                Object.assign(defs_item, delta_item)
            }
        });
    });
    
    gridOptions.api.setColumnDefs(defs)
}

// return the gridOptions object for the specific scope
function TVJS_GridOptions(scope_id) {
    return WebIO.scopes[scope_id].table.gridOptions
}

// refresh the cells of the specific grid
function TVJS_RefreshCells(scope_id) {
    var gridOptions = TVJS_GridOptions(scope_id)

    var params = {
        force: true,
        suppressFlash: true,
    };
    gridOptions.api.refreshCells(params);        
}


// iterate over all the columnDefs properties (recursivlly) and replace any string that starts 
// with "tvjs_func " or property that ends with _jsfunc by using the eval function
// this is needed in order to overcome the JSExpr limitation of sending class names and functions in a Julia Dict object
function TVJS_ConvertJSFunctions(scope_id) {
    var gridOptions = TVJS_GridOptions(scope_id)
    var columnDefs = gridOptions.columnDefs
    TVJS_ConvertJSFunctions_Recursive(columnDefs)
    console.log("TVJS_ConvertJSFunctions --------------------------")
    console.log(columnDefs)
    console.log("TVJS_ConvertJSFunctions --------------------------")
    gridOptions.api.setColumnDefs(columnDefs)
}

function TVJS_ConvertJSFunctions_Recursive(obj) {
    for (var property in obj) {
        if (obj.hasOwnProperty(property)) {
            if (typeof obj[property] === "object") {
                TVJS_ConvertJSFunctions_Recursive(obj[property]);
            } 
            else 
            {
                if (typeof obj[property] === 'string') {

                    if (obj[property].substring(0, 10) == 'tvjs_func ') {
                        console.log("ITERATE CHANGING " + property)
                        obj[property] = eval(obj[property].substring(10))
                    }
                }
                if (property.endsWith("_jsfunc")) {
                    var new_property = property.slice(0,-7)
                    console.log("ITERATE CHANGING " + property + " -> " + new_property)
                    console.log(obj[property])
                    obj[new_property] = eval(obj[property])
                }
            }
        }
    }
}

// insert a column at a specific location in the grid
function TVJS_InsertColumnBefore(scope_id, field_name, new_column) {
    // console.log("TVJS_InsertColumnBefore Start")
    var gridOptions = TVJS_GridOptions(scope_id)
    var columnDefs = gridOptions.columnDefs
    index = columnDefs.findIndex((x) => x.field === field_name)
    columnDefs.push(new_column);

    gridOptions.api.setColumnDefs(columnDefs)
    if (index !== -1) {
        console.log("switching")
        gridOptions.columnApi.moveColumnByIndex(columnDefs.length - 1, index);
    }

    var cols = gridOptions.columnApi.getAllGridColumns();
    var colToNameFunc = function (col, index) {
      return index + ' = ' + col.getId();
    };
    var colNames = cols.map(colToNameFunc).join(', ');
}

