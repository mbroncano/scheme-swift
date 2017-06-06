//
//  main.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

let environment = Environment()

// (define (foo n) (display n) (foo (+ 1 n))) (foo 0)
// (define (fib n) (fib-iter 1 0 n)) (define (fib-iter a b count) (if (= count 0) b (fib-iter (+ a b) a (- count 1)))) (fib 100)

while true {
    do {
        print("> ", terminator: "")
        if let input = readLine() {
            var car = try Node(input).car()
            while case let .Pointer(first) = car {
                let cell = Cell(car: first.car, cdr: .Nil)
                //                print("~# ", cell.display)
                try print("=", environment.eval(cell.car).display)
                print(environment.stack)
                car = first.cdr
            }
        }
    } catch {
        print(error)
    }
}
