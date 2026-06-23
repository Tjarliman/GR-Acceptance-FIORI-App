sap.ui.define(
    ["sap/ui/core/UIComponent", "sap/ui/model/json/JSONModel"],
    function (UIComponent, JSONModel) {
        "use strict";

        return UIComponent.extend("zmm.gracceptance.Component", {
            metadata: {
                manifest: "json"
            },

            init: function () {
                UIComponent.prototype.init.apply(this, arguments);
                this.getRouter().initialize();

                var oLocalModel = new JSONModel({
                    warehouseNumber: "",
                    scanEngine: "",
                    scanFrame: "",
                    scannedItems: [],
                    busy: false
                });
                this.setModel(oLocalModel, "local");
            }
        });
    }
);
