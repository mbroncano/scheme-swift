//
//  Builtin.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/8/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

func op4(_ op: @escaping (Decimal, Decimal) -> Bool) -> Procedure {
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

func op3(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
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

func op2(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
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

func pred(_ op: @escaping (Datum) -> Bool) -> Procedure {
    return { env, args in
        guard case let .Pointer(first) = args
            else { throw Exception.General("Internal error: \(args) must be a list") }

        guard let arg = first.next(), arg.next() == nil
            else { throw Exception.General("Must provide one argument") }

        return .Boolean(op(arg.car))
    }
}

func pred2(_ op: @escaping (Datum, Datum) -> Bool) -> Procedure {
    return { env, args in
        guard case let .Pointer(first) = args
            else { throw Exception.General("Internal error: \(args) must be a list") }

        guard let arg = first.next(), let second = arg.next()
            else { throw Exception.General("Must provide two arguments") }

        return .Boolean(op(arg.car, second.car))
    }
}

func arglist(_ args: Datum) throws -> Cell {
    guard case let .Pointer(list) = args
        else { throw Exception.General("Internal error: \(args) must be a list") }

    return list
}

func arg1list(_ list: Cell) throws -> Cell {
    guard let first = list.next(), case .Nil = first.cdr
        else { throw Exception.General("Must provide one arguments") }

    guard case let .Pointer(res) = first.car
        else { throw Exception.General("Argument must be a list, got \(first.car)") }

    return res
}

func arg2datum(_ list: Cell) throws -> (Cell, Cell) {
    guard let first = list.next(), let second = first.next()
        else { throw Exception.General("Must provide two arguments") }

    return (first, second)
}

func procany(_ op: @escaping (Cell) -> Datum) -> Procedure {
    return { env, args in
        let list = try arglist(args)

        return (op(list))
    }
}

func proc1list(_ op: @escaping (Cell) -> Datum) -> Procedure {
    return { env, args in
        let list = try arglist(args)
        let first = try arg1list(list)

        return (op(first))
    }
}

func proc2datum(_ op: @escaping (Cell, Cell) -> Datum) -> Procedure {
    return { env, args in
        let list = try arglist(args)
        let (first, second) = try arg2datum(list)

        return (op(first, second))
    }
}

func proc1list1datum(_ op: @escaping (Cell, Cell) -> Void) -> Procedure {
    return { env, args in
        let list = try arglist(args)
        let (first, second) = try arg2datum(list)

        guard case let .Pointer(pair) = first.car
            else { throw Exception.General("First param must be a pair") }

        op(pair, second)

        return .Undefined
    }
}

let builtin:[Datum] = [
    .Procedure("+", op2(+, 0)),
    .Procedure("*", op2(*, 1)),
    .Procedure("-", op3(-, 0)),
    .Procedure("/", op3(/, 1)),
    .Procedure("<", op4(<)),
    .Procedure(">", op4(>)),
    .Procedure("=", op4(==)),
    .Procedure("<=",op4(<=)),
    .Procedure(">=",op4(>=)),
    .Procedure("null?", pred({ $0.isNil })),
    .Procedure("pair?", pred({ $0.isPair })),
    .Procedure("zero?", pred({ $0.isZero })),
    .Procedure("number?", pred({ $0.isNumber })),
    .Procedure("string?", pred({ $0.isString })),
    .Procedure("symbol?", pred({ $0.isSymbol })),
    .Procedure("port?", pred({ $0.isPort })),
    .Procedure("eq?", pred2({ $0 == $1 })),
    .Procedure("car", proc1list({ $0.car })),
    .Procedure("cdr", proc1list({ $0.cdr })),
    .Procedure("cons", proc2datum({ .Pointer(Cell(car:$0.car, cdr:$1.car)) })),
    .Procedure("set-car!", proc1list1datum({ $0.car = $1.car })),
    .Procedure("set-cdr!", proc1list1datum({ $0.cdr = $1.car })),
    .Procedure("list", procany({ $0.cdr })),
    
    // replace this with a library
    .Procedure("error", { env, args in try env.eval(Node.parse("display 'error")) }),
    .Procedure("newline", { env, args in try env.eval(Node.parse("display")) }),
    .Procedure("map", { env, args in
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

    .Procedure("display", { env, args in
        guard case var .Pointer(first) = args
            else { throw Exception.General("Internal error: \(args) must be a list") }

        while let next = first.next() {
            print(next.car.display)
            first = next
        }
        return .Undefined
    }),

    .Procedure("read", { env, args in
        guard case var .Pointer(first) = args
            else { throw Exception.General("Internal error: \(args) must be a list") }

        if let line = readLine() {
            return .Symbol(line)
        }

        return .Undefined
    }),
    
    .Procedure("apply", { env, args in
        let list = try arglist(args)
        let (first, second) = try arg2datum(list)

        return try env.eval(.Pointer(Cell(car: first.car, cdr:second.car)))
    }),

    // -------------------------------------------------------------------------------

    .SpecialForm("lambda", { env, cell in
        guard case let .Pointer(first) = cell, case .Pointer = first.cdr
            else { throw Exception.General("Must provide at least two parameters") }

        // TODO: filter the closure for the free variables in the lambda body(s)
        let new = Closure(env: env.close(), formal: first.car, body: first.cdr)
        return (.Closure(new), false)
    }),

//    .SpecialForm("let", { env, cell in
//        guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
//            else { throw Exception.General("Must provide at least two parameters") }
//
//        // TODO: add support for named letrec
//        //            if case let .Symbol(vars) = first.car {
//        //
//        //            }
//
//        guard case var .Pointer(vars) = first.car
//            else { throw Exception.General("First parameter must be a list") }
//
//        // evaluate the formals
//        var cdr = vars.cdr
//        while true {
//            guard case let .Pointer(formal) = vars.car else { throw Exception.General("Expected format to be lists") }
//            guard case let .SpecialForm(_, define) = try env.resolve("define") else { throw Exception.General("asdf") }
//            try define(env, formal)
//
//            guard case let .Pointer(next) = vars.cdr else { break }
//            vars = next
//        }
//
//        // evaluate the expressions left to right
//        var result: Datum = .Nil
//        var body = second
//        while true {
//            guard case let .Pointer(next) = body.cdr
//                else { return (body.car, true) }
//            _ = try env.eval(body.car)
//            body = next
//        }
//
//        // return the last result
//        //return (.Nil, false)
//    }),

    .SpecialForm("if", { env, cell in
        guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
            else { throw Exception.General("Must provide at least two parameters") }

        if try env.eval(first.car).isTrue {
            return (second.car, true)
        }

        if case let .Pointer(third) = second.cdr {
            return (third.car, true)
        }

        return (.Undefined, false)
    }),

    .SpecialForm("else", { _, _ in return (.Boolean(true), false) }),
    .SpecialForm("cond", { env, cell in
        guard case var .Pointer(arg) = cell
            else { throw Exception.General("Must provide at least one parameters") }

        while true {
            guard case var .Pointer(clause) = arg.car
                else { throw Exception.General("Clause must be a list") }
            let pred = try env.eval(clause.car)
            if pred.isTrue {
                guard case var .Pointer(exp) = clause.cdr else { return (pred, false) }
                while true {
                    guard case let .Pointer(next) = exp.cdr else { return (exp.car, true) }
                    exp = next
                    let _ = try env.eval(exp.car)
                }
                break
            }
            guard let nextClause = arg.next() else { break }
            arg = nextClause
        }

        return (.Undefined, false)
    }),

    .SpecialForm("quote", { env, cell in
        guard case let .Pointer(first) = cell
            else { throw Exception.General("Must provide at least a parameter") }

        return (first.car, false)
    }),

    .SpecialForm("define", { env, cell in
        guard case let .Pointer(first) = cell
            else { throw Exception.General("Must provide at least a parameter") }

        // first form: (define <symbol> <expression>)
        if case let .Symbol(symbol) = first.car {
            var value: Datum = .Nil
            if case let .Pointer(def) = first.cdr {
                let evaluate = true
                value = evaluate ? try env.eval(def.car) : def.car
            }

            env.define_var(symbol, value)

        // second form: (define (<symbol> <formal>) <expression>)
        } else if case let .Pointer(lambda) = first.car {
            guard case .Pointer = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            guard case let .Symbol(symbol) = lambda.car
                else { throw Exception.General("Lambda name must be a symbol") }

            env.define_var(symbol, .Closure(Closure(env: env.close(), formal: lambda.cdr, body: first.cdr)))

        } else {
            throw Exception.General("Define must be a symbol or a lambda")
        }

        return (.Undefined, false)
    })
]

