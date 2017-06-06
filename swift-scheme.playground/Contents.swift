import Foundation

do {
    let environment = Environment()
//        var car = try Node("(number? (if (> 2 3) 'a (+ 2 3))) (+) (*)").car()
//    var car = try Node("(letrec ((a 1)(b (+ a 2))) (define c (+ a b)) c)").car()
    var car = try Node("((lambda x x) 2)").car()

    while case let .Pointer(first) = car {
        let cell = Cell(car: first.car, cdr: .Nil)
        print("~# " + cell.display)
        try print("=> " + environment.eval(cell.car).display)
        car = first.cdr
    }

} catch {
    print(error)
}

