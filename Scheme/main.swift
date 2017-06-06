//
//  main.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

let environment = Environment()

while true {
    do {
        print("> ", terminator: "")
        if let input = readLine() {
            var car = try Node(input).car()
            while case let .Pointer(first) = car {
                let cell = Cell(car: first.car, cdr: .Nil)
                //                print("~# ", cell.display)
                try print("=", environment.eval(cell.car).display)
                car = first.cdr
            }
        }
    } catch {
        print(error)
    }
}
