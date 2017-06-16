//
//  Tests.swift
//  Tests
//
//  Created by Manuel Broncano on 6/16/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import XCTest

class Tests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSimple() {
        do {
            let env = try Environment()
            XCTAssertEqual(try env.readLine(input: "(null? '())"), "#t")
            XCTAssertEqual(try env.readLine(input: "(+ 1 2)"), "3")
            XCTAssertEqual(try env.readLine(input: "(+)"), "0")
            XCTAssertEqual(try env.readLine(input: "(*)"), "1")
            XCTAssertEqual(try env.readLine(input: "(- 3)"), "-3")
            XCTAssertEqual(try env.readLine(input: "(- 3 4)"), "-1")
            XCTAssertEqual(try env.readLine(input: "(< 1 2)"), "#t")
            XCTAssertEqual(try env.readLine(input: "(= 1 2)"), "#f")
            XCTAssertEqual(try env.readLine(input: "(number? (* 1 2))"), "#t")
            XCTAssertEqual(try env.readLine(input: "(pair? '(* 1 2))"), "#t")
            XCTAssertEqual(try env.readLine(input: "(cons 1 2)"), "(1 . 2)")
            XCTAssertEqual(try env.readLine(input: "(define l (list 1 2 'a 'b)) l"), "(1 2 a b)")
            XCTAssertEqual(try env.readLine(input: "(map number? '(1 2 a))"), "(#t #t #f)")
            XCTAssertEqual(try env.readLine(input: "(cond ((> 2 3) 'less)(else 'more))"), "more")
            XCTAssertEqual(try env.readLine(input: "(define my-pair (cons 1 2)) (set-car! my-pair 4) (set-cdr! my-pair 8) my-pair"), "(4 . 8)")

            XCTAssertEqual(try env.readLine(input: "(car l)"), "1")
            XCTAssertEqual(try env.readLine(input: "(cdr l)"), "(2 a b)")
            XCTAssertEqual(try env.readLine(input: "(define a (+ 4 5)) a"), "9")
            let loop =
"""
(let loop ((numbers '(3 -2 1 6 -5)) (nonneg '()) (neg '()))
    (cond ((null? numbers)
             (list nonneg neg))
          ((>= (car numbers) 0)
             (loop (cdr numbers) (cons (car numbers) nonneg) neg))
          (else (loop (cdr numbers) nonneg (cons (car numbers) neg)))))
"""
            XCTAssertEqual(try env.readLine(input: loop), "((6 1 3) (-5 -2))")
            let fib =
"""
(define (fib n)
    (fib-iter 1 0 n))

(define (fib-iter a b count)
    (if (= count 0) b (fib-iter (+ a b) a (- count 1))))

(define is-even?
    (lambda (n) (if (= n 0) #t (is-odd? (- n 1)))))

(define is-odd?
    (lambda (n) (if (= n 0) #f (is-even? (- n 1)))))

(fib 100)
"""
            XCTAssertEqual(try env.readLine(input: fib), "354224848179261915075")
            XCTAssertEqual(try env.readLine(input: "(is-even? (fib 55))"), "#t")

        } catch {
            XCTFail("Exception: \(error)")
        }
    }
}
