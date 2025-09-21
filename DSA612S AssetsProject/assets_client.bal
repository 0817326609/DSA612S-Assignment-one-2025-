import ballerina/http;
import ballerina/io;

public function main() returns error? {
    
    http:Client assetClient = check new("http://localhost:8080/assets");

        function printResult(string action, http:Response res) returns error? {
        int status = res.statusCode;
        string body = check res.getText();
        io:println("\n>>> " + action);
        io:println("[HTTP " + status.toString() + "] " + body);
    }

    //  1) Create a new asset
    json newAsset = {
        "assetTag": "EQ-001",
        "name": "3D Printer",
        "faculty": "Computing & Informatics",
        "department": "Software Engineering",
        "status": "ACTIVE",
        "acquiredDate": "2024-03-10",
        "components": [],
        "schedules": [],
        "workOrders": []
    };
    var respCreate = assetClient->post("/", newAsset);
    if respCreate is http:Response {
        printResult("Creating asset EQ-001", respCreate);
    }

    // 2) Update asset status
    var respUpdate = assetClient->put("/EQ-001", { "status": "UNDER_REPAIR" });
    if respUpdate is http:Response {
        printResult("Updating asset EQ-001 status to UNDER_REPAIR", respUpdate);
    }

    // 3) View all assets
    var respAll = assetClient->get("/");
    if respAll is http:Response {
        printResult("Fetching all assets", respAll);
    }

    // 4) View assets by faculty
    var respFaculty = assetClient->get("/faculty/Computing%20%26%20Informatics");
    if respFaculty is http:Response {
        printResult("Fetching assets for Computing & Informatics", respFaculty);
    }

    //5) Add a maintenance schedule
    var respAddSched = assetClient->post("/EQ-001/schedules",
        { "id": "S-1", "frequency": "quarterly", "nextDue": "2025-06-01" });
    if respAddSched is http:Response {
        printResult("Adding schedule S-1 to EQ-001", respAddSched);
    }

    //6) Check overdue maintenance
    var respOverdue = assetClient->get("/overdue?today=2025-09-21");
    if respOverdue is http:Response {
        printResult("Checking overdue assets for today", respOverdue);
    }

    //7) Add a component
    var respAddComp = assetClient->post("/EQ-001/components",
        { "id": "C-1", "name": "Extruder Motor" });
    if respAddComp is http:Response {
        printResult("Adding component C-1 to EQ-001", respAddComp);
    }

    //8) Add a work order
    var respAddWO = assetClient->post("/EQ-001/workorders",
        { "id": "WO-1", "status": "OPEN" });
    if respAddWO is http:Response {
        printResult("Adding work order WO-1 to EQ-001", respAddWO);
    }

    //9) Add a task to the work order
    var respAddTask = assetClient->post("/EQ-001/workorders/WO-1/tasks",
        { "id": "T-1", "desc": "Replace nozzle" });
    if respAddTask is http:Response {
        printResult("Adding task T-1 to work order WO-1", respAddTask);
    }

    //10) Remove the task
    var respDelTask = assetClient->delete("/EQ-001/workorders/WO-1/tasks/T-1");
    if respDelTask is http:Response {
        printResult("Deleting task T-1 from work order WO-1", respDelTask);
    }

    //11) Remove the component
    var respDelComp = assetClient->delete("/EQ-001/components/C-1");
    if respDelComp is http:Response {
        printResult("Deleting component C-1 from EQ-001", respDelComp);
    }

    //12) Remove the schedule
    var respDelSched = assetClient->delete("/EQ-001/schedules/S-1");
    if respDelSched is http:Response {
        printResult("Deleting schedule S-1 from EQ-001", respDelSched);
    }

    //13) Delete the asset
    var respDelAsset = assetClient->delete("/EQ-001");
    if respDelAsset is http:Response {
        printResult("Deleting asset EQ-001", respDelAsset);
    }

    io:println("\n>>> client finished. All steps completed.");
}

