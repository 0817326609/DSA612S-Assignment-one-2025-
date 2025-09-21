import ballerina/io;
import ballerina/grpc;
import gen.carrental;

public function main() returns error? {
    carrental:CarRentalClient client = check new (http://localhost:9090);

    carrental:AddCarRequest carReq = {
        car: {
            plate: "N1125W",
            make: "Toyota",
            model: "Hilux",
            year: 2022,
            daily_price: 350.0,
            mileage: 12000,
            status: carrental:CarStatus::AVAILABLE
        }
    };
    var carResponse = check client->AddCar(carReq);
    io:println(AddCar response:, carResponse);

       var userStream = check client->CreateUsers();
    check userStream.send({ 
        username: "johnny", 
        role: carrental:Role::CUSTOMER, 
        fullname: "Johnny Namene", 
        email: "johnny.namene@namcar.com.na" 
    });
    check userStream.send({ 
        username: "helen", 
        role: carrental:Role::ADMIN, 
        fullname: "Helen Shikongo", 
        email: "helen.shikongo@caradmin.na" 
    });
    var usersResponse = check userStream.complete();
    io:println("CreateUsers response:", usersResponse);

    var availableCars = check client->ListAvailableCars({ filter: "Toyota" });
    while true {
        var car = availableCars.next();
        if car is error {
            break;
        } else {
            io:println("Available car:", car);
        }
    }

    var cartResponse = check client->AddToCart({
        username: "johnny",
        plate: "N1125W",
        start_date: "2025-10-01",
        end_date: "2025-10-05"
    });
    io:println("AddToCart response:", cartResponse);

    var reservationResponse = check client->PlaceReservation({ username: "johnny" });
    io:println("PlaceReservation response:", reservationResponse);

}
