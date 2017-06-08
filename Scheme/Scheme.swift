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

public typealias Procedure = (Environment, Datum) throws -> Datum
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
            return "\(cdr.display)"
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
    case Procedure(String, Procedure)
    case Symbol(String)
    case String(String)
    case SpecialForm(String, (Environment, Datum) throws -> (Datum, Bool))
    case Closure([String:Datum], Datum)

    // TODO: implement eq?, eqv? and eqvalue?
    public var isNil: Bool {
        guard case .Nil = self else { return false }
        return true
    }

    public var isNull: Bool {
        guard case let .Pointer(cell) = self, case .Nil = cell.car else { return false }
        return true
    }

    public var isTrue: Bool {
        guard case let .Boolean(bool) = self else { return true }
        return bool
    }

    public var isNumber: Bool {
        guard case .Number = self else { return false }
        return true
    }

    public var isString: Bool {
        guard case .String = self else { return false }
        return true
    }

    public var isSymbol: Bool {
        guard case .Symbol = self else { return false }
        return true
    }

    public var isPair: Bool {
        guard case .Pointer = self else { return false }
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
        case let .String(string):
            return "#<string: \"@\(string)\">"
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
        case let .String(string):
            return "\"\(string)\""
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
                } else if let start = text.first, start == "\"" {
                    return .String(String(text.dropFirst().dropLast()))
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

        var string = false
        while let c = iter.next() {
            if c == "\"" {
                if string {
                    text.append(c)
                    try add()
                } else {
                    try add()
                    text.append(c)
                }

                string = !string
                continue
            }

            if string {
                text.append(c)
                continue
            }

            switch c {
            case "\"":
                if string {

                } else {
                    string = true
                }

            case ";":
                while let n = iter.next(), n != "\n" {}

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

    static func op4(_ op: @escaping (Decimal, Decimal) -> Bool) -> Procedure {
        return { env, args in
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

    static func op3(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
        return { env, args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let next = first.next()
                else { throw Exception.General("Parameter required") }
            guard case let .Number(number) = next.car
                else { throw Exception.General("\(next.car) must be a number") }
            guard case .Pointer = next.cdr
                else { return .Number(op(def, number)) }

            return try op2(op, number)(env, first.cdr)
        }
    }

    static func op2(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
        return { env, args in
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

    static func pred(_ op: @escaping (Datum) -> Bool) -> Procedure {
        return { env, args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let arg = first.next(), arg.next() == nil
                else { throw Exception.General("Must provide one argument") }

            return .Boolean(op(arg.car))
        }
    }

    static func pred2(_ op: @escaping (Datum, Datum) -> Bool) -> Procedure {
        return { env, args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let arg = first.next(), let second = arg.next()
                else { throw Exception.General("Must provide two arguments") }

            return .Boolean(op(arg.car, second.car))
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
        "null?": .Procedure("null?", Environment.pred({ $0.isNil })),

        "set-cdr!": .Procedure("set-car!", { env, args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let arg = first.next(), let second = arg.next()
                else { throw Exception.General("Must provide two arguments") }

            guard case .Pointer = arg.car
                else { throw Exception.General("First param must be a pair") }

            arg.cdr = second.car

            return .Nil
        }),

        "set-car!": .Procedure("set-car!", { env, args in
            guard case let .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let arg = first.next(), let second = arg.next()
                else { throw Exception.General("Must provide two arguments") }

            guard case .Pointer = arg.car
                else { throw Exception.General("First param must be a pair") }

            arg.car = second.car

            return .Nil
        }),

        "eq?": .Procedure("eq?", Environment.pred2({ first, second in
            switch (first, second) {
            case (.Nil, .Nil):
                return true
            case (let .Boolean(lhs), let .Boolean(rhs)):
                return lhs == rhs
            case (let .Number(lhs), let .Number(rhs)):
                return lhs == rhs
            case (let .Character(lhs), let .Character(rhs)):
                return lhs == rhs
            case (let .String(lhs), let .String(rhs)):
                return lhs == rhs
            case (let .Symbol(lhs), let .Symbol(rhs)):
                return lhs == rhs
            case (.Pointer, .Pointer): fallthrough // unspecified
            case (.Procedure, .Procedure): fallthrough // unspecified
            case (.Closure, .Closure): fallthrough // unspecified
            case (.SpecialForm, .SpecialForm): fallthrough // unspecified
            default:
                return false
            }

        })),

        "cons": .Procedure("cons", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let first = list.next(), let second = first.next()
                else { throw Exception.General("Must provide two arguments") }

            return .Pointer(Cell(car:first.car, cdr:second.car))
        }),

        "cdr": .Procedure("cdr", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let next = list.next(), case let .Pointer(res) = next.car
                else { throw Exception.General("First parameter must be a list: \(list.cdr.display)") }

            return res.cdr
        }),

        "car": .Procedure("car", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let next = list.next(), case let .Pointer(res) = next.car
                else { throw Exception.General("First parameter must be a list: \(list.cdr.display)") }

            return res.car
        }),

        "list": .Procedure("list", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            return list.cdr
        }),

        "apply": .Procedure("apply", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let first = list.next(), case let .Procedure(_ , proc) = first.car
                else { throw Exception.General("First parameter must be a procedure: \(list.cdr)") }

            guard case let .Pointer(second) = first.cdr
                else { throw Exception.General("Second parameter must be a list: \(first.cdr)") }

            // TODO: replace by eval
            return try proc(env, .Pointer(Cell(car: first.car, cdr:second.car)))
        }),

        "map": .Procedure("map", { env, args in
            guard case var .Pointer(list) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            guard let first = list.next() //, case let .Procedure(_ , proc) = first.car
                else { throw Exception.General("First parameter must be a procedure: \(list.cdr)") }

            guard case let .Pointer(second) = first.cdr
                else { throw Exception.General("Second parameter must be a list: \(first.cdr)") }

            guard case let .Pointer(item) = second.car
                else { return .Pointer(Cell(car: .Nil, cdr: .Nil)) }

            var it = item
            var dd = [Datum]()
            while true {
                // hyper hack to support lambdas
                let arg: Datum = .Pointer(Cell(car:.Pointer(Cell(car: .Symbol("quote"), cdr:.Pointer(Cell(car: it.car, cdr:.Nil)))), cdr: .Nil))
//                let res = try proc(.Pointer(Cell(car: first.car, cdr: arg)))
                let res = try env.eval(.Pointer(Cell(car: first.car, cdr: arg)))
                dd.append(res)
                guard let next = it.next() else { break }
                it = next
            }

            let map: Datum = dd.reversed().reduce(it.cdr, { acc, ptr in
                return .Pointer(Cell(car: ptr, cdr: acc))
            })

            return map

//            return try proc(.Pointer(Cell(car: first.car, cdr:second.car)))
        }),

        "display": .Procedure("display", { env, args in
            guard case var .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

           while let next = first.next() {
                print(next.car.display)
                first = next
            }
            return .Nil
        }),

        "error": .Procedure("error", { env, args in
            guard case var .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            print("error: ", terminator: "")
            while let next = first.next() {
                print(next.car.display)
                first = next
            }
            return .Nil
        }),

        "newline": .Procedure("newline", { env, args in print(""); return .Nil }),

        "read": .Procedure("read", { env, args in
            guard case var .Pointer(first) = args
                else { throw Exception.General("Internal error: \(args) must be a list") }

            if let line = readLine() {
                return .Symbol(line)
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
        "string?": .Procedure("string?", Environment.pred({ $0.isString })),
        "symbol?": .Procedure("symbol?", Environment.pred({ $0.isSymbol })),
        "pair?": .Procedure("symbol?", Environment.pred({ $0.isPair })),
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


            if case let .Symbol(vars) = first.car {

            }

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

        "else": .Boolean(true),
        "cond": .SpecialForm("cond", { env, cell in
            guard case var .Pointer(arg) = cell
                else { throw Exception.General("Must provide at least one parameters") }

            while true {
                guard case var .Pointer(clause) = arg.car
                    else { throw Exception.General("Clause must be a list") }
                let pred = try env.eval(clause.car)
                if pred.isTrue {
                    guard case var .Pointer(exp) = clause.cdr else { return (pred, false) }
                    while true {
                        let res = try env.eval(exp.car)
                        guard case let .Pointer(next) = exp.cdr else { return (res, false) }
                        exp = next
                    }
                    break
                }
                guard let nextClause = arg.next() else { break }
                arg = nextClause
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

        // ... or the iterative version
//        var it = c
//        var dd = [Datum]()
//        while let next = it.next() {
//            dd.append(try eval(next.car))
//            it = next
//        }
//        
//        let arg: Datum = dd.reversed().reduce(it.cdr, { acc, ptr in
//            return .Pointer(Cell(car: ptr, cdr: acc))
//        })


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

                    let arg = try eval_args(c.cdr)

                    // we actually ignore the first 'car'
                    result = try proc(self, .Pointer(Cell(car: e, cdr: arg)))
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

//                    if case .Pointer = c.cdr {
                    let args = try eval_args(c.cdr)

                    guard case let .Pointer(formal) = lambda, case let .Pointer(body) = formal.cdr
                        else { throw Exception.General("Error in lambda formal and/or body") }

                    // bind the variables
                    switch formal.car {
                    case .Nil:
                        break

                    case let .Symbol(symbol):
                        define_var(symbol, args)

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

                    default:
                        throw Exception.General("Formal must be a list, symbol or nothing")
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

