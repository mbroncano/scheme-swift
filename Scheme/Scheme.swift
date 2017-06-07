//
//  Scheme.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

public enum Exception: Error {
    case General(String)
}

public class Cell: CustomStringConvertible {
    var car: Datum
    var cdr: Datum

    init(car: Datum, cdr: Datum) {
        self.car = car
        self.cdr = cdr
    }

    public func next() -> Cell? {
        if case let .Pointer(result) = cdr {
            return result
        }
        return nil
    }

    public var description: String {
        return "#(\(car), \(cdr))"
    }

    public var display: String {
        switch (car, cdr) {
        case (.Nil, _):
            return "() \(cdr.display)"
        case (_, .Nil):
            return car.display
        case (_, let .Pointer(cell)):
            return "\(car.display) \(cell.display)"
        default:
            return "\(car.display) . \(cdr.display)"
        }
    }
}


public indirect enum Datum: CustomStringConvertible {
    case Nil
    case Pointer(Cell)
    case Number(Decimal)
    case Character(Character)
    case Boolean(Bool)
    case Procedure(String, (Datum) throws -> Datum)
    case Symbol(String)
    case SpecialForm(String, (Environment, Datum) throws -> (Datum, Bool))
    case Closure([String:Datum], Datum)

    // TODO: implement eq?, eqv? and eqvalue?

    public var isNil: Bool {
        guard case .Nil = self else { return true }
        return false
    }

    public var isTrue: Bool {
        guard case let .Boolean(bool) = self else { return true }
        return bool
    }

    public var isNumber: Bool {
        guard case .Number = self else { return false }
        return true
    }

    public var isZero: Bool {
        guard case let .Number(number) = self else { return false }
        return number == 0
    }

    public var description: String {
        switch self {
        case .Nil:
            return "#<nil>"
        case let .Pointer(cell):
            return "#<cell: \(cell)>"
        case let .Number(number):
            return "#<number: \(number)>"
        case let .Boolean(value):
            return "#<boolean: \(value)>"
        case let .Character(value):
            return "#<character: \(value)>"
        case let .Symbol(string):
            return "#<symbol: @\(string)>"
        case let .Procedure(name, _):
            return "#<procedure: @\(name)>"
        case let .SpecialForm(name, _):
            return "#<special: @\(name)>"
        case let .Closure(_, formal):
            return "#<closure: @\(formal)>"
        }
    }

    public var display: String {
        switch self {
        case .Nil:
            return ""
        case let .Symbol(string):
            return string
        case let .Number(value):
            return "\(value)"
        case let .Character(char):
            return "#\\\(char)"
        case let .Boolean(value):
            return (value ? "#t" : "#f")
        case let .Pointer(cell):
            return "(\(cell.display))"
        default:
            return "\(self)"
        }
    }
}

public indirect enum Node: CustomStringConvertible {
    case Atom(String)
    case List([Node])

    public var description: String {
        switch self {
        case let .Atom(string):
            return "#<\(string)>"
        case let .List(list):
            return "(" + list.map{ "\($0)" }.joined(separator: " ") + ")"
        }
    }

    public var isQuote: Bool {
        guard case let .Atom(text) = self, text == "'" else { return false }
        return true
    }

    public var isDot: Bool {
        guard case let .Atom(text) = self, text == "." else { return false }
        return true
    }

    public func car() -> Datum {
        switch self {
        case let .Atom(text):
            switch text {
            case "":
                return .Nil
            case "#t":
                return .Boolean(true)
            case "#f":
                return .Boolean(false)
            default:
                if let _ = Float(text), let number = Decimal(string: text) {
                    return .Number(number)
                } else {
                    return .Symbol(text)
                }
            }
        case let .List(list):
            var last: Datum = .Nil
            for cell in list.reversed() {
                if cell.isQuote {
                    var lastcdr: Datum = .Nil
                    if case let .Pointer(lastcell) = last {
                        lastcdr = lastcell.cdr
                        lastcell.cdr = .Nil
                    }
                    let quote = Cell(car: .Symbol("quote"), cdr: last)
                    let list = Cell(car: .Pointer(quote), cdr: lastcdr)
                    last = .Pointer(list)
                } else if cell.isDot {
                    if case let .Pointer(lastcell) = last {
                        last = lastcell.car
                    }
                } else {
                    let new = Cell(car: cell.car(), cdr: last)
                    last = .Pointer(new)
                }
            }
            return last
        }
    }

    init(_ string: String) throws {
        var iter = string.characters.makeIterator()
        var text = ""
        var stack: [Node] = [.List([])]

        let add = {
            if !text.isEmpty {
                guard let last = stack.popLast(), case let .List(list) = last
                    else { throw Exception.General("Parsing") }

                stack.append(.List( list + [.Atom(text)]))
                text = ""
            }
        }

        while let c = iter.next() {
            switch c {
            case "(":
                try add()
                stack.append(.List([]))

            case ")":
                guard let last = stack.popLast(), case var .List(list) = last
                    else { throw Exception.General("Parsing") }

                if !text.isEmpty {
                    list.append(.Atom(text))
                    text = ""
                }

                guard let prev = stack.popLast(), case let .List(plist) = prev
                    else { throw Exception.General("Parsing") }

                stack.append(.List( plist + [.List(list)] ))

            case " ", "\n":
                try add()

            case "'":
                if text.isEmpty {
                    text = "'"
                    try add()
                }

            default:
                text.append(c)
            }
        }
        try add()

        guard let first = stack.first else { throw Exception.General("Umatched parenthesis") }
        self = first
    }
}

public class Environment {

    func resolve(_ symbol:String) throws -> Datum {
        for frame in self.stack.reversed() {
            if let value = frame[symbol] {
                return value
            }
        }
        throw Exception.General("Unbound symbol: \(symbol)")
    }

    static func op4(_ op: @escaping (Decimal, Decimal) -> Bool) -> (Datum) throws -> Datum {
        return { args in
            guard case let .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let first = list.next(), var iter = first.next()
                else { throw Exception.General("Two parameters required") }
            guard case var .Number(lhs) = first.car
                else { throw Exception.General("Parameters must be numbers: \(first.car)") }


            repeat {
                guard case let .Number(rhs) = iter.car
                    else { throw Exception.General("Parameters must be numbers: \(iter.car)") }

                if !op(lhs, rhs) { return .Boolean(false) }

                lhs = rhs
                guard let next = iter.next() else { return .Boolean(true) }
                iter = next
            } while true
        }
    }

    static func op3(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> (Datum) throws -> Datum {
        return { args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let next = first.next()
                else { throw Exception.General("Parameter required") }
            guard case let .Number(number) = next.car
                else { throw Exception.General("\(next.car) must be a number") }
            guard case .Pointer = next.cdr
                else { return .Number(op(def, number)) }

            return try op2(op, number)(first.cdr)
        }
    }

    static func op2(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> (Datum) throws -> Datum {
        return { args in
            guard case var .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            var acc = def
            while let next = first.next() {
                guard case let .Number(number) = next.car
                    else { throw Exception.General("\(next.car) must be a number") }
                acc = op(acc, number)
                first = next
            }
            return .Number(acc)
        }
    }

    static func pred(_ op: @escaping (Datum) -> Bool) -> (Datum) throws -> Datum {
        return { args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let arg = first.next(), arg.next() == nil
                else { throw Exception.General("Must provide one argument") }

            return .Boolean(op(arg.car))
        }
    }

    func extend(_ ext: [String:Datum] = [:]) {
        self.stack.append(ext)
    }

    func unextend() {
        _ = self.stack.popLast()
    }

    func define_var(_ symbol: String, _ value: Datum) {
        if var last = stack.popLast() {
            last[symbol] = value
            stack.append(last)
        }
    }

    func define(_ first: Cell, evaluate: Bool = true) throws {
        if case let .Symbol(symbol) = first.car {
            var value: Datum = .Nil
            if case let .Pointer(def) = first.cdr {
                value = evaluate ? try eval(def.car) : def.car
            }

            define_var(symbol, value)

        } else if case let .Pointer(lambda) = first.car {
            guard case .Pointer = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            guard case let .Symbol(symbol) = lambda.car
                else { throw Exception.General("Lambda name must be a symbol") }

            define_var(symbol, .Closure(close(), .Pointer(Cell(car: lambda.cdr, cdr: first.cdr))))

        } else {
            throw Exception.General("Define must be a symbol or a lambda")
        }
    }

    func close() -> [String: Datum] {
        return stack.reduce([:]) { (acc, frame) in
            var cur = acc
            for (key, value) in frame {
                cur[key] = value
            }
            return cur
        }
    }

    var stack: [[String: Datum]] = [[
        "display": .Procedure("display", {args in
            guard case var .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

           while let next = first.next() {
                print(next.car.display)
                first = next
            }
            return .Nil
        }),
        "+": .Procedure("add", Environment.op2(+, 0)),
        "*": .Procedure("mul", Environment.op2(*, 1)),
        "-": .Procedure("sub", Environment.op3(-, 0)),
        "/": .Procedure("div", Environment.op3(/, 1)),
        "<": .Procedure("lt", Environment.op4(<)),
        ">": .Procedure("gt", Environment.op4(>)),
        "=": .Procedure("eq", Environment.op4(==)),
        "<=": .Procedure("le", Environment.op4(<=)),
        ">=": .Procedure("ge", Environment.op4(>=)),
        "number?": .Procedure("number?", Environment.pred({ $0.isNumber })),
        "zero?": .Procedure("zero?", Environment.pred({ $0.isZero })),
        "lambda": .SpecialForm("lambda", { env, cell in
            guard case let .Pointer(first) = cell, case .Pointer = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            return (.Closure(env.close(), cell), false)
        }),
        "let": .SpecialForm("let", { env, cell in
            // TODO: add support for named letrec
            guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            guard case var .Pointer(vars) = first.car
                else { throw Exception.General("First parameter must be a list") }

            // evaluate the formals
            var cdr = vars.cdr
            while true {
                guard case let .Pointer(formal) = vars.car else { throw Exception.General("Expected format to be lists") }
                try env.define(formal)

                guard case let .Pointer(next) = vars.cdr else { break }
                vars = next
            }

            // evaluate the expressions left to right
            var result: Datum = .Nil
            var body = second
            while true {
                guard case let .Pointer(next) = body.cdr
                    else { return (body.car, true) }
                _ = try env.eval(body.car)
                body = next
            }

            // return the last result
            //return (.Nil, false)
        }),
        "if": .SpecialForm("if", { env, cell in
            guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            if try env.eval(first.car).isTrue {
                return (second.car, true)
            }

            if case let .Pointer(third) = second.cdr {
                return (third.car, true)
            }

            return (.Nil, false)
        }),
        "quote": .SpecialForm("quote", { env, cell in
            guard case let .Pointer(first) = cell
                else { throw Exception.General("Must provide at least a parameter") }

            return (first.car, false)
        }),
        "define": .SpecialForm("define", { env, cell in
            guard case let .Pointer(first) = cell
                else { throw Exception.General("Must provide at least a parameter") }

            try env.define(first)

            return (.Nil, false)
        })]]

    func eval_args(_ datum: Datum) throws -> Datum {
        if case let .Pointer(cell) = datum {
            let ecar = try eval(cell.car)
            let ecdr = try eval_args(cell.cdr)
            let ecell = Cell(car: ecar, cdr: ecdr)
            return .Pointer(ecell)
        } else if case let .Symbol(symbol) = datum {
            return try resolve(symbol)
        } else {
            return datum
        }
    }

    // TODO: http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-14.html#node_sec_11.20
    func eval(_ car: Datum, _ tail: Bool = false) throws -> Datum {

        var car = car
        var result: Datum = .Nil
        var tail = tail

        repeat {
            if case let .Pointer(c) = car {
                let e = try eval(c.car)
                if case let .Procedure(_ , proc) = e {

                    // TODO: use a proper list instead of Array
                    // the current way doesn't support improper lists
//                    var last = c.cdr
//                    var args = [Datum]()
//                    while case let .Pointer(cell) = last {
//                        try args.append(eval(cell.car))
//                        last = cell.cdr
//                    }

                    // evaluate the expressions left to right
                    var iter = c
                    var cell = Cell(car: .Nil, cdr: .Nil)
                    let res: Datum = .Pointer(cell)
                    while true {
                        cell.car = try eval(iter.car)
                        guard case let .Pointer(next) = iter.cdr else { break }
                        iter = next

                        let new = Cell(car: .Nil, cdr: .Nil)
                        cell.cdr = .Pointer(new)
                        cell = new
                    }

                    result = try proc(res)
                    break;

                } else if case let .SpecialForm(_, form) = e {

                    let (res, eval) = try form(self, c.cdr)
                    if !eval {
                        result = res
                        break
                    }

                    tail = true
                    car = res

                } else if case let .Closure(frame, lambda) = e {
                    if !tail {
                        extend(frame)
                    }

                    guard case .Pointer = c.cdr else { throw Exception.General("Proper list required for evaluation")}
                    let args = try eval_args(c.cdr)

                    guard case let .Pointer(formal) = lambda, case let .Pointer(body) = formal.cdr
                        else { throw Exception.General("Error in lambda formal and/or body") }

                    // bind the variables
                    switch formal.car {
                    case var .Pointer(list):
                        var args = args
                        while true {
                            guard case let .Symbol(symbol) = list.car,
                                case let .Pointer(value) = args
                                else { break }
                            define_var(symbol, value.car)

                            if case let .Pointer(next) = list.cdr {
                                list = next
                            } else if case let .Symbol(rest) = list.cdr {
                                define_var(rest, value.cdr)
                                break
                            } else if case .Nil =  list.cdr {
                                break
                            } else {
                                throw Exception.General("The 'rest' parameter should be a symbol \(list.cdr)")
                            }

                            guard case .Pointer = value.cdr else { break }
                            args = value.cdr
                        }
                    case let .Symbol(symbol):
                        define_var(symbol, args)
                    default:
                        throw Exception.General("Formal must be a list or a symbol")
                    }

                    // evaluate the expressions left to right
                    var iter = body
                    while true {
                        guard case let .Pointer(next) = iter.cdr else { break }
                        result = try eval(iter.car)
                        iter = next
                    }

                    tail = true
                    car = iter.car

                } else {
                    throw Exception.General("Not a procedure, special form or closure \(e)")
                }
            } else if case let .Symbol(s) = car {
                result = try resolve(s)
                break;
            } else {
                result = car
                break;
            }
        } while true

        if tail {
            unextend()
        }

        return result
    }

    init() {
    }
}

