import ballerina/http;
import ballerina/io;
import ballerina/file;
import ballerina/time;

// Main storage for assets
map<json> assets = {};
listener http:Listener apiListener = new(8080);

final string DB_FILE = "assets_db.json";

// --- Load the database from JSON file at startup
function loadAssetsFromFile() {
    if file:exists(DB_FILE) {
        var content = file:readFileAsString(DB_FILE);
        if content is string && content.trim().length() > 0 {
            var parsed = content.fromJsonString();
            if parsed is json {
                assets = <map<json>>parsed;
                io:println("Assets loaded: " + assets.length().toString());
            }
        }
    }
}

// --- Save assets map to disk after every modification
function persistAssets() {
    string jsonStr = assets.toJsonString();
    checkpanic file:writeFile(DB_FILE, jsonStr);
}

// --- Check if a string is a valid yyyy-MM-dd date
function validDate(string dateStr) returns boolean {
    var parsed = time:parse(dateStr, "yyyy-MM-dd");
    return parsed is time:Utc;
}

// --- Helper to fetch asset or return 404
function getAssetOr404(string tag) returns json?|http:Response {
    if assets.hasKey(tag) {
        return assets[tag];
    }
    http:Response res = new;
    res.statusCode = 404;
    res.setJsonPayload({ "error": "Asset not found for tag: " + tag });
    return res;
}

service /assets on apiListener {

    // --- Load DB at startup
    init {
        loadAssetsFromFile();
    }

    // --- Create a new asset
    resource function post .(http:Request req) returns http:Response|error {
        http:Response res = new;
        json payload = check req.getJsonPayload();

        // Validate required fields
        if !(payload.assetTag is string && payload.name is string &&
             payload.faculty is string && payload.department is string &&
             payload.status is string && payload.acquiredDate is string) {
            res.statusCode = 400;
            res.setJsonPayload({ "error": "Missing some required fields. Check payload." });
            return res;
        }

        string assetTag = <string>payload.assetTag;
        if assets.hasKey(assetTag) {
            res.statusCode = 400;
            res.setJsonPayload({ "error": "Asset tag already exists. Try a new one." });
            return res;
        }

        if !validDate(<string>payload.acquiredDate) {
            res.statusCode = 400;
            res.setJsonPayload({ "error": "acquiredDate must be yyyy-MM-dd" });
            return res;
        }

        json asset = payload.clone();

        // Initialize empty arrays if missing
        if asset.components is () { asset.put("components", []); }
        if asset.schedules is () { asset.put("schedules", []); }
        if asset.workOrders is () { asset.put("workOrders", []); }

        assets[assetTag] = asset;
        persistAssets();

        res.statusCode = 201;
        res.setJsonPayload({ "message": "Asset successfully created", "asset": asset });
        return res;
    }

    // --- Get all assets
    resource function get .() returns http:Response|error {
        http:Response res = new;
        json[] list = [];
        foreach var [_, a] in assets.entries() {
            list.push(a);
        }
        res.statusCode = 200;
        res.setJsonPayload({ "count": list.length(), "assets": list });
        return res;
    }

    // --- Get asset by tag
    resource function get [string assetTag]() returns http:Response|error {
        http:Response res = new;
        var asset = getAssetOr404(assetTag);
        if asset is http:Response {
            return asset;
        }
        res.statusCode = 200;
        res.setJsonPayload(asset);
        return res;
    }

    // --- Update asset
    resource function put [string assetTag](http:Request req) returns http:Response|error {
        http:Response res = new;
        var asset = getAssetOr404(assetTag);
        if asset is http:Response { return asset; }

        json payload = check req.getJsonPayload();

        // Merge updates
        foreach var [k, v] in payload.entries() {
            asset[k] = v;
        }

        assets[assetTag] = asset;
        persistAssets();

        res.statusCode = 200;
        res.setJsonPayload({ "message": "Asset updated", "asset": asset });
        return res;
    }

    // --- Delete asset
    resource function delete [string assetTag]() returns http:Response|error {
        http:Response res = new;
        if !assets.hasKey(assetTag) {
            res.statusCode = 404;
            res.setJsonPayload({ "error": "Asset not found to delete" });
            return res;
        }
        assets.remove(assetTag);
        persistAssets();
        res.statusCode = 200;
        res.setJsonPayload({ "message": "Deleted asset", "assetTag": assetTag });
        return res;
    }

    // --- Get assets by faculty
    resource function get faculty/[string facultyName]() returns http:Response|error {
        http:Response res = new;
        json[] list = [];
        foreach var [_, a] in assets.entries() {
            if a.faculty is string && <string>a.faculty == facultyName {
                list.push(a);
            }
        }
        res.statusCode = 200;
        res.setJsonPayload({ "count": list.length(), "assets": list });
        return res;
    }

}