sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
], function (Controller, MessageBox, MessageToast, Filter, FilterOperator) {
    "use strict";

    return Controller.extend("zmm.gracceptance.controller.Main", {

        onInit: function () {
            this._oLocalModel = this.getOwnerComponent().getModel("local");
            this._oODataModel = this.getOwnerComponent().getModel();
            this._oLocalModel.setProperty("/lastEngine", "");
            this._loadDefaultWarehouse();
        },

        // ─── Default warehouse from EWM parameter /SCWM/LGN ────────────
        _loadDefaultWarehouse: function () {
            var oBinding = this._oODataModel.bindList("/SerialLookup", undefined, undefined, undefined, {
                $select: "SerialNumber,WarehouseNumber"
            });
            oBinding.requestContexts(0, 1).then(function (aContexts) {
                var oObj = (aContexts && aContexts.length > 0) ? aContexts[0].getObject() : null;
                if (oObj && oObj.WarehouseNumber) {
                    this._oLocalModel.setProperty("/warehouseNumber", oObj.WarehouseNumber);
                }
            }.bind(this)).catch(function () {
                // no default available - user can still type the warehouse
            });
        },

        // ─── Engine Scan ───────────────────────────────────────────────
        onEngineScan: function () {
            var sEngine = this._oLocalModel.getProperty("/scanEngine").trim().toUpperCase();
            var sWarehouse = this._oLocalModel.getProperty("/warehouseNumber").trim().toUpperCase();

            if (!sWarehouse) {
                MessageBox.error(this._getText("msgWarehouseRequired"));
                return;
            }
            if (!sEngine) {
                return;
            }

            this._oLocalModel.setProperty("/warehouseNumber", sWarehouse);
            this._oLocalModel.setProperty("/scanEngine", sEngine);
            this._oLocalModel.setProperty("/busy", true);

            var oListBinding = this._oODataModel.bindList("/SerialLookup", undefined, undefined, [
                new Filter("SerialNumber", FilterOperator.EQ, sEngine),
                new Filter("WarehouseNumber", FilterOperator.EQ, sWarehouse)
            ]);

            oListBinding.requestContexts(0, 1).then(function (aContexts) {
                this._oLocalModel.setProperty("/busy", false);

                if (!aContexts || aContexts.length === 0) {
                    MessageBox.error(this._getText("msgEngineLookupFailed"));
                    this._oLocalModel.setProperty("/scanEngine", "");
                    this.byId("inputEngine").focus();
                    return;
                }

                var oData = aContexts[0].getObject();

                if (oData.Message) {
                    MessageBox.error(oData.Message);
                    this._oLocalModel.setProperty("/scanEngine", "");
                    this.byId("inputEngine").focus();
                    return;
                }

                this._oLocalModel.setProperty("/lastEngine", sEngine);
                this._oLocalModel.setProperty("/lastMaterial", oData.Material);
                this._oLocalModel.setProperty("/lastMaterialDesc", oData.MaterialDesc);

                setTimeout(function () {
                    this.byId("inputFrame").focus();
                }.bind(this), 100);
            }.bind(this)).catch(function (oError) {
                this._oLocalModel.setProperty("/busy", false);
                MessageBox.error(this._getText("msgEngineLookupFailed") + "\n" + (oError.message || ""));
                this._oLocalModel.setProperty("/scanEngine", "");
            }.bind(this));
        },

        // ─── Frame Scan ────────────────────────────────────────────────
        onFrameScan: function () {
            var sFrame = this._oLocalModel.getProperty("/scanFrame").trim().toUpperCase();
            var sEngine = this._oLocalModel.getProperty("/lastEngine");
            var sWarehouse = this._oLocalModel.getProperty("/warehouseNumber");

            if (!sEngine) {
                MessageBox.error(this._getText("msgScanEngineFirst"));
                return;
            }
            if (!sFrame) {
                return;
            }

            this._oLocalModel.setProperty("/busy", true);

            // Re-query with the scanned UII included so the backend can
            // validate it (via SERIALNUMBER_READ / EQUI-UII) server-side.
            var oListBinding = this._oODataModel.bindList("/SerialLookup", undefined, undefined, [
                new Filter("SerialNumber", FilterOperator.EQ, sEngine),
                new Filter("WarehouseNumber", FilterOperator.EQ, sWarehouse),
                new Filter("Uii", FilterOperator.EQ, sFrame)
            ]);

            oListBinding.requestContexts(0, 1).then(function (aContexts) {
                this._oLocalModel.setProperty("/busy", false);

                if (!aContexts || aContexts.length === 0) {
                    MessageBox.error(this._getText("msgEngineLookupFailed"));
                    this._oLocalModel.setProperty("/scanFrame", "");
                    this.byId("inputFrame").focus();
                    return;
                }

                var oData = aContexts[0].getObject();

                if (oData.Message) {
                    MessageBox.error(oData.Message);
                    this._oLocalModel.setProperty("/scanFrame", "");
                    this.byId("inputFrame").focus();
                    return;
                }

                var aItems = this._oLocalModel.getProperty("/scannedItems") || [];
                var iNextNo = aItems.length + 1;

                aItems.push({
                    No: iNextNo,
                    Material: oData.Material,
                    MaterialDesc: oData.MaterialDesc,
                    SerialNumber: sEngine,
                    FrameNumber: sFrame,
                    Status: "OK"
                });

                this._oLocalModel.setProperty("/scannedItems", aItems);
                this._oLocalModel.setProperty("/scanEngine", "");
                this._oLocalModel.setProperty("/scanFrame", "");
                this._oLocalModel.setProperty("/lastEngine", "");
                this._oLocalModel.setProperty("/lastMaterial", "");
                this._oLocalModel.setProperty("/lastMaterialDesc", "");

                MessageToast.show(this._getText("msgFrameAdded"));
                this.byId("inputEngine").focus();
            }.bind(this)).catch(function (oError) {
                this._oLocalModel.setProperty("/busy", false);
                MessageBox.error(this._getText("msgEngineLookupFailed") + "\n" + (oError.message || ""));
                this._oLocalModel.setProperty("/scanFrame", "");
            }.bind(this));
        },

        // ─── Delete Selected Item ────────────────────────────────────
        onDeleteItem: function () {
            var oTable = this.byId("scannedItemsTable");
            var oSelectedItem = oTable.getSelectedItem();

            if (!oSelectedItem) {
                MessageBox.warning(this._getText("selectItemToDelete"));
                return;
            }

            var sPath = oSelectedItem.getBindingContext("local").getPath();
            var iIndex = parseInt(sPath.split("/").pop(), 10);
            var aItems = this._oLocalModel.getProperty("/scannedItems").slice();

            aItems.splice(iIndex, 1);
            for (var i = 0; i < aItems.length; i++) {
                aItems[i].No = i + 1;
            }
            this._oLocalModel.setProperty("/scannedItems", aItems);
            oTable.removeSelections(true);
            MessageToast.show(this._getText("msgItemDeleted"));
        },

        // ─── Post Goods Movement 301 ───────────────────────────────────
        onPost: function () {
            var aItems = this._oLocalModel.getProperty("/scannedItems") || [];
            if (aItems.length === 0) {
                MessageBox.error(this._getText("msgNoItemsToPost"));
                return;
            }

            var sWarehouse = this._oLocalModel.getProperty("/warehouseNumber");

            MessageBox.confirm(
                this._getText("msgConfirmPost", [aItems.length]),
                {
                    onClose: function (sAction) {
                        if (sAction === MessageBox.Action.OK) {
                            this._executePost(sWarehouse, aItems);
                        }
                    }.bind(this)
                }
            );
        },

        _executePost: function (sWarehouse, aItems) {
            this._oLocalModel.setProperty("/busy", true);

            var aPayload = aItems.map(function (oItem) {
                return {
                    Material: oItem.Material,
                    SerialNumber: oItem.SerialNumber,
                    Uii: oItem.FrameNumber
                };
            });

            var sItemsJson = JSON.stringify(aPayload);
            var sServicePath = this._oODataModel.getServiceUrl();
            var sActionPath = sServicePath + "SerialLookup/com.sap.gateway.srvd.zmmsd_gracceptance.v0001.postGoodsMovement";

            var oPayload = {
                WarehouseNumber: sWarehouse,
                ItemsJson: sItemsJson
            };

            this._oODataModel.submitBatch("$auto");

            fetch(sActionPath, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "X-CSRF-Token": this._oODataModel.getHttpHeaders()["X-CSRF-Token"] || "Fetch"
                },
                body: JSON.stringify(oPayload)
            }).then(function (response) {
                return response.json();
            }).then(function (oResult) {
                this._oLocalModel.setProperty("/busy", false);
                var oData = oResult.value || oResult;

                if (oData.Success === true || oData.Success === "X") {
                    MessageBox.success(
                        oData.Message || this._getText("msgPostSuccess", [oData.MaterialDocument]),
                        {
                            onClose: function () {
                                this._oLocalModel.setProperty("/scannedItems", []);
                            }.bind(this)
                        }
                    );
                } else {
                    MessageBox.error(this._getText("msgPostFailed", [oData.Message || "Unknown error"]));
                }
            }.bind(this)).catch(function (oError) {
                this._oLocalModel.setProperty("/busy", false);
                MessageBox.error(this._getText("msgPostFailed", [oError.message || "Network error"]));
            }.bind(this));
        },

        // ─── Helpers ───────────────────────────────────────────────────
        _getText: function (sKey, aArgs) {
            var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();
            return oBundle.getText(sKey, aArgs);
        }
    });
});
