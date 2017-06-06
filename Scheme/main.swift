//
//  main.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

do {
    let environment = Environment()
    //        var car = try Node("(number? (if (> 2 3) 'a (+ 2 3))) (+) (*)").car()
    //    var car = try Node("(letrec ((a 1)(b (+ a 2))) (define c (+ a b)) c)").car()
//    var car = try Node("((lambda (x y z) (+ 1 x y) z) 1 2 ''a)").car()
//    var car = try Node("((lambda (x y . z) (+ x y)) 1 2 3 4)").car()
//    var car = try Node("(define add (lambda (x y) (+ x y))) (add 1 2)").car()
//    var car = try Node("(define fib (lambda (n) (if (<= n 2) 1 (+ (fib (- n 1)) (fib (- n 2)))))) (fib 10)").car()
//    var car = try Node("(define (fib n) (if (<= n 2) 1 (+ (fib (- n 1)) (fib (- n 2))))) (fib 20)").car()
    var car = try Node("""
    (define (zero? n)
        (= 0 n))

    (define (fib n)
        (fib-iter 1 0 n))

    (define (fib-iter a b count)
        (if (= count 0)
            b
            (fib-iter (+ a b) a (- count 1))))

    (fib 500)
    """).car() // TCO-FTW
//    var car = try Node("(define (fact x acc) (if (zero? x) acc (fact (- x 1) (* x acc)))) (fact 100 1)").car()

    while case let .Pointer(first) = car {
        let cell = Cell(car: first.car, cdr: .Nil)
        print("~# " + cell.display)
        try print("=> " + environment.eval(cell.car).display)
        car = first.cdr
    }

} catch {
    print(error)
}

