

function DecodePosition(p) {
    found = p.match(/^\((?<X>.*),(?<Y>.*),(?<Z>.*),(?<tX>.*),(?<tY>.*),(?<tZ>.*)\)$/);    
    if (found == null) {
        return null;
    } else {
        return found.groups;
    }
}

function EncodePosition(X, Y, Z, tX, tY, tZ) {
    res = "(" + X + "," + Y + "," + Z + "," + tX + "," + tY + "," + tZ + ")" 
    if (res === "(,,,,,)") {
        res = ""
    }
    return res;
}


class PositionPopupCellEditor {
    init(params) {
        this.container = document.createElement('div');
        this.container.setAttribute('class', 'input-widget-popup');
        this._createTable(params);
        this._registerApplyListener();
        this.params = params;
        this.value = params.value;
    }

    getGui() {
        return this.container;
    }

    destroy() {
        this.applyButton.removeEventListener('click', this._applyValues);
    }

    afterGuiAttached() {
        this.container.focus();
    }

    getValue() {
        this._constructValue()
        return this.value;
    }

    isPopup() {
        return true;
    }

    _createTable(params) {
        this.container.innerHTML = `
            <p style="text-align: center;font-size: large;">Position Parameters<p>
            <table cellspacing="40px" cellpadding="40px">
                <tr>
                    <td>Translation</td>
                    <td>X=</td>
                    <td><input type="text" id="X" name="X"></td>
                    <td>Y=</td>
                    <td><input type="text" id="Y" name="Y"></td>
                    <td>Z=</td>
                    <td><input type="text" id="Z" name="Z"></td>
                </tr>
                <tr>
                    <td>Rotation</td>
                    <td>X=</td>
                    <td><input type="text" id="tX" name="tX"></td>
                    <td>Y=</td>
                    <td><input type="text" id="tY" name="tY"></td>
                    <td>Z=</td>
                    <td><input type="text" id="tZ" name="tZ"></td>
                </tr>
                <tr>
                    <td><button id="applyBtn">Apply</button></td>
                </tr>
            </table>
        `;

        this.X = this.container.querySelector('#X');
        this.Y = this.container.querySelector('#Y');
        this.Z = this.container.querySelector('#Z');
        this.tX = this.container.querySelector('#tX');
        this.tY = this.container.querySelector('#tY');
        this.tZ = this.container.querySelector('#tZ');

        this.value = params.value.trim()
        var values = DecodePosition(this.value)
        if (values !== null) {
            this.X.value = values.X
            this.Y.value = values.Y
            this.Z.value = values.Z
            this.tX.value = values.tX
            this.tY.value = values.tY
            this.tZ.value = values.tZ
        }

        // console.log("PARAMS")
        // console.log(params)
    }

    _registerApplyListener() {
        this.applyButton = this.container.querySelector('#applyBtn');
        this.applyButton.addEventListener('click', () => this._applyValues()) //this._applyValues);
    }

    _constructValue() {
        this.value = EncodePosition(
            this.X.value,
            this.Y.value,
            this.Z.value,
            this.tX.value,
            this.tY.value,
            this.tZ.value,
        )
    }

    _applyValues() {
        this.params.stopEditing();
    }

}


class PositionCellRenderer {
    init(params) {
        this.gui = document.createElement('span');
        if (this._isNotNil(params.value)
            && (this._isNumber(params.value) || this._isNotEmptyString(params.value))) {

            this.gui.style.cssText = 'color:red;background-color:yellow';

            var display_str = "undefined"                
            var values = DecodePosition(params.value.trim())
            if (values !== null) {
                display_str = `Translation[${values.X}, ${values.Y}, ${values.Z}]  Rotation[${values.tX}, ${values.tY}, ${values.tZ}]`
            }   
            
            // this.gui.innerText = `[[ ${params.value.toLocaleString()} ]]`;
            this.gui.innerHTML = display_str
        } else {
            this.gui.innerText = '';
        }
    }

    _isNotNil(value) {
        return value !== undefined && value !== null;
    }

    _isNotEmptyString(value) {
        return typeof value === 'string' && value !== '';
    }

    _isNumber(value) {
        return !Number.isNaN(Number.parseFloat(value)) && Number.isFinite(value);
    }

    getGui() {
        return this.gui;
    }
}
