//
//  Builtin.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/8/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

func cmpHelper(_ op: @escaping (Decimal, Decimal) -> Bool) -> Procedure {
    return {
        try .Boolean(nil == zip($1.dropFirst().dropLast(), $1.dropFirst(2)).first(where: {
            try !op($0.0.asNumber(), $0.1.asNumber())
        }))
    }
}

func subHelper(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
    return { env, args in
        guard case let .Pointer(first) = args
            else { throw Exception.General("Internal error: \(args) must be a list") }

        guard let next = first.next()
            else { throw Exception.General("Parameter required") }
        guard case let .Number(number) = next.car
            else { throw Exception.General("\(next.car) must be a number") }
        guard case .Pointer = next.cdr
            else { return .Number(op(def, number)) }

        return try sumHelper(op, number)(env, first.cdr)
    }
}

func sumHelper(_ op: @escaping (Decimal, Decimal) -> Decimal, _ def: Decimal) -> Procedure {
    return { try .Number($1.dropFirst().reduce(def, { try op($0, $1.asNumber()) })) }
}

let builtin:[Datum] = [
    // arithmetic
    .Procedure("+", sumHelper(+, 0)),
    .Procedure("*", sumHelper(*, 1)),
    .Procedure("-", subHelper(-, 0)),
    .Procedure("/", subHelper(/, 1)),
    .Procedure("<", cmpHelper(<)),
    .Procedure(">", cmpHelper(>)),
    .Procedure("=", cmpHelper(==)),
    .Procedure("<=",cmpHelper(<=)),
    .Procedure(">=",cmpHelper(>=)),

    // predicates
    .Procedure("null?", { .Boolean($1[1].isNull) }),
    .Procedure("pair?", { .Boolean($1[1].isPair) }),
    .Procedure("zero?", { .Boolean($1[1].isZero) }),
    .Procedure("number?", { .Boolean($1[1].isNumber) }),
    .Procedure("string?", { .Boolean($1[1].isString) }),
    .Procedure("symbol?", { .Boolean($1[1].isSymbol) }),
    .Procedure("port?", { .Boolean($1[1].isPort) }),
    .Procedure("eq?", { .Boolean($1[1] == $1[2]) }),

    // list returns a copy of the provided one
    .Procedure("cons", { .Pointer(Cell(car:$1[1], cdr:$1[2])) }),
    .Procedure("list", { $1.dropFirst().reversed().reduce(.Nil, { .Pointer(Cell(car: $1, cdr: $0)) }) }),
    .Procedure("car", { try $1[1].asPointer().car }),
    .Procedure("cdr", { try $1[1].asPointer().cdr }),
    .Procedure("set-car!", { try $1[1].asPointer().car = $1[2]; return .Undefined }),
    .Procedure("set-cdr!", { try $1[1].asPointer().cdr = $1[2]; return .Undefined }),

    // replace this with a library
    .Procedure("error", { env, args in try env.eval(Node.parse("display 'error")) }),
    .Procedure("newline", { env, args in try env.eval(Node.parse("display")) }),

    .Procedure("map", { env, args in
        let proc = args[1]
        let list = try Datum.Pointer(args[2].asPointer())
        return try list.reversed().reduce(.Nil, { cur, car in
            // (<proc> <item>)
//            let eval = Datum.Pointer(Cell(car:proc, cdr:.Pointer(Cell(car:car, cdr:.Nil))))
//            return try .Pointer(Cell(car: env.eval(eval), cdr: cur))
            return try .Pointer(Cell(car: env.eval_proc(proc, .Pointer(Cell(car:car, cdr:.Nil))), cdr: cur))
        })
    }),

    .Procedure("display", { print($1[1].display); return .Undefined }),
    .Procedure("read", { _,_ in
        guard let line = readLine() else { return .Undefined }
        return .Symbol(line)
    }),
    
    .Procedure("apply", { env, args in
        let list = try Datum.Pointer(args[2].asPointer())
        let eval = Datum.Pointer(Cell(car:args[1], cdr:list))

        return try env.eval(eval)
    }),

    // -------------------------------------------------------------------------------

    .SpecialForm("lambda", { env, cell in
        guard case let .Pointer(first) = cell, case .Pointer = first.cdr
            else { throw Exception.General("Must provide at least two parameters") }

        // TODO: filter the closure for the free variables in the lambda body(s)
        let new = Closure(env: env.close(), formal: first.car, body: first.cdr)
        return (.Closure(new), false)
    }),

    .SpecialForm("begin", { env, args in
        return try (args.reduce(.Nil, { try env.eval($1) }), true)
    }),

    // (let [<name>] ((<var> <assign>) ...) (<expr>) ...)
    // (([define <name>] ((lambda (<var>) (<expr>) ...) <assign> ...)))
    .SpecialForm("let", { env, args in
        var args = args[...]
        let name: String?
        if let first = args.first, first.isSymbol {
            name = try args.removeFirst().asSymbol()
        } else {
            name = nil
        }

        let (formal, assign) = args.removeFirst().reversed().reduce((.Nil, .Nil), { cur, car in
            return (.Pointer(Cell(car: car[0], cdr: cur.0)), .Pointer(Cell(car: car[1], cdr: cur.1)))
        })
        let body = Datum(slice: args)
        let closure = Closure(env: [:], formal: formal, body: body)

        return try env.eval_closure(closure, assign, name)
    }),

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
        guard let arg = cell.first else {
            throw Exception.General("Must provide at least a parameter")
        }

        return (arg, false)
    }),

    .SpecialForm("define", { env, cell in
        guard let first = cell.first else {
            throw Exception.General("Must provide at least a parameter")
        }

        let name: String
        let value: Datum
        switch first {
        case let .Symbol(symbol):
            name = symbol
            value = try env.eval(cell[1])
        case let .Pointer(lambda):
            name = try lambda.car.asSymbol()
            value = .Closure(Closure(env: env.close(), formal: lambda.cdr, body: Datum(slice: cell[1...])))
        default:
            throw Exception.General("Must be symbol or list: \(first)")
        }

        env.define_var(name, value)

        return (.Undefined, false)
    })
]

