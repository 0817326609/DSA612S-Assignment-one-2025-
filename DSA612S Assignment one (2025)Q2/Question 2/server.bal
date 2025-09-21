import ballerina/log;
import ballerina/time;
import ballerina/grpc;
import gen.carrental;

map<carrental:Car> cars = {};
map<string, carrental:User> users = {};
map<string, carrental:Reservation> reservations = {};
map<string, carrental:ReservationItem[]> carts = {};

function parseDate(string d) returns time:Utc|error {
    return time:parse(d, "yyyy-MM-dd");
}

function daysBetween(string start, string end) returns int|error {
    time:Utc s = check parseDate(start);
    time:Utc e = check parseDate(end);
    int diffSec = time:utcToEpochSeconds(e) - time:utcToEpochSeconds(s);
    if diffSec <= 0 {
        return error("end date must be after start date");
    }
    int days = diffSec / 86400;
    if days == 0 {
        days = 1;
    }
    return days;
}

service object CarRentalService {

    remote function AddCar(carrental:AddCarRequest req) 
        returns carrental:AddCarResponse|error {
        carrental:Car c = req.car;
        if c.plate == "" {
            return { ok: false, plate: "", message: "plate is required" };
        }
        if cars.hasKey(c.plate) {
            return { ok: false, plate: c.plate, message: "car already exists" };
        }
        cars[c.plate] = c;
        log:printInfo("Car added: " + c.plate);
        return { ok: true, plate: c.plate, message: "car created" };
    }

    remote function CreateUsers(stream<carrental:User, error?> userStream) 
        returns carrental:OpResponse|error {
        int count = 0;
        while true {
            var next = userStream.next();
            if next is error {
                if next.message() == "End of stream" {
                    break;
                } else {
                    return { ok: false, message: "stream error: " + next.message() };
                }
            } else if next is carrental:User {
                users[next.username] = next;
                count += 1;
            } else {
                break;
            }
        }
        return { ok: true, message: "created " + count.toString() + " users" };
    }

    remote function ListAvailableCars(carrental:ListAvailableRequest req)
        returns stream<carrental:Car, error?>|error {
        stream<carrental:Car, error?> s = new;
        _ = start function () returns error? {
            string filter = req.filter;
            foreach var [_, c] in cars.entries() {
                if (c.status == carrental:CarStatus::AVAILABLE &&
                    (filter == "" ||
                    c.make.toLowerAscii().contains(filter.toLowerAscii()) ||
                    c.model.toLowerAscii().contains(filter.toLowerAscii()) ||
                    c.plate.toLowerAscii().contains(filter.toLowerAscii()))) {
                        _ = s.next(c);
                }
            }
            _ = s.complete();
            return;
        }();
        return s;
    }

    remote function AddToCart(carrental:AddToCartRequest req) 
        returns carrental:AddToCartResponse|error {
        if !users.hasKey(req.username) {
            return { ok: false, message: "user not found" };
        }
        if !cars.hasKey(req.plate) {
            return { ok: false, message: "car not found" };
        }

        var days = daysBetween(req.start_date, req.end_date);
        if days is error {
            return { ok: false, message: "date error: " + days.message() };
        }

        carrental:Car c = cars[req.plate];
        if c.status != carrental:CarStatus::AVAILABLE {
            return { ok: false, message: "car not available" };
        }

        double price = days * c.daily_price;
        carrental:ReservationItem item = {
            plate: req.plate,
            start_date: req.start_date,
            end_date: req.end_date,
            price: price
        };

        if carts.hasKey(req.username) {
            var arr = carts[req.username];
            arr.push(item);
            carts[req.username] = arr;
        } else {
            carts[req.username] = [item];
        }

        return { ok: true, message: "added to cart" };
    }

    remote function PlaceReservation(carrental:PlaceReservationRequest req) 
        returns carrental:PlaceReservationResponse|error {
        string username = req.username;
        if !users.hasKey(username) {
            return { ok: false, message: "user not found", reservations: [] };
        }
        if !carts.hasKey(username) {
            return { ok: false, message: "cart empty", reservations: [] };
        }

        carrental:ReservationItem[] items = carts[username];

        foreach var item in items {
            if !cars.hasKey(item.plate) {
                return { ok: false, message: "car removed: " + item.plate, reservations: [] };
            }
            carrental:Car c = cars[item.plate];
            if c.status != carrental:CarStatus::AVAILABLE {
                return { ok: false, message: "not available: " + item.plate, reservations: [] };
            }
            c.status = carrental:CarStatus::RENTED;
            cars[item.plate] = c;
        }

        string id = "R-" + time:currentTime().toString();
        string nowStr = time:currentTime().toString();
        carrental:Reservation res = {
            id: id,
            username: username,
            items: items,
            created_at: nowStr
        };
        reservations[id] = res;
        carts.remove(username);

        return { ok: true, message: "reservation placed", reservations: items };
    }
}

// Run gRPC listener
public function main() returns error? {
    grpc:Listener listener = new (9090);
    service object svc = new CarRentalService();
    check listener.attach(svc);
    check listener.start();
    log:printInfo("Car Rental gRPC server running on port 9090");

    // Keep the server running
    check runtime:sleep(1000 * 60 * 60 * 24);

}
