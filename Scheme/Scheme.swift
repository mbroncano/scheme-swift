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


/// The Scheme execution environment
public class Environment {

    func resolve(_ symbol:String) throws -> Datum {
        for frame in self.stack.reversed() {
            if let value = frame[symbol] {
                return value
            }
        }
        throw Exception.General("Unbound symbol: \(symbol)")
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

    func close() -> [String: Datum] {
        return stack.reduce([:]) { (acc, frame) in
            var cur = acc
            for (key, value) in frame {
                cur[key] = value
            }
            return cur
        }
    }

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

    func eval_bind(_ formal: Datum, _ args: Datum) throws {
        // bind the variables
        switch formal {
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
    }

    func eval_closure(_ closure: Closure, _ arguments: Datum, _ name: String? = nil) throws -> (Datum, Bool) {
        guard case let .Pointer(body) = closure.body
            else { throw Exception.General("Error in lambda body") }

        // create frame if the last one wasn't create by this same closure
        if let last = stack.last, let owner = last["__owner__"],
            owner == .Closure(closure) {} else {
            var frame = closure.env
            frame["__owner__"] = .Closure(closure)
            self.extend(frame)
            if let name = name {
                define_var(name, .Closure(closure))
            }
        }

        // bind the arguments and the formals
        try eval_bind(closure.formal, eval_args(arguments))

        // evaluate the expressions left to right
        var iter = body
        while true {
            guard case let .Pointer(next) = iter.cdr else { break }
            _ = try eval(iter.car)
            iter = next
        }

        return (iter.car, true)
    }

    func eval_proc(_ proc: Datum, _ arguments: Datum) throws -> Datum {
        switch proc {
        case let .Procedure(_ , procedure):
            let arg = Datum.Pointer(Cell(car: proc, cdr: arguments))
            let res = try procedure(self, arg)
            return res

        case let .Closure(closure):
            let (res, _) = try eval_closure(closure, arguments.asPointer().car)
            return res

        default:
            throw Exception.General("Not a procedure or closure \(proc)")
        }
    }

    func eval_list(_ proc: Datum, _ arguments: Datum) throws -> (Datum, Bool) {
        switch proc {
        case let .Procedure(_ , procedure):
            // TODO: do not send the procedure name
            let arg = try Datum.Pointer(Cell(car: proc, cdr: eval_args(arguments)))
            let res = try procedure(self, arg)
            return (res, false)

        case let .SpecialForm(_, form):
            return try form(self, arguments)

        case let .Closure(closure):
            return try eval_closure(closure, arguments)

        default:
            throw Exception.General("Not a procedure, special form or closure \(proc)")
        }
    }

    // TODO: http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-14.html#node_sec_11.20
    func eval(_ car: Datum) throws -> Datum {
        var car = car
        var result: Datum?
        let cur = stack.count

        while case .none = result {
            switch car {
            case let .Pointer(c):
                let (res, eval) = try eval_list(self.eval(c.car), c.cdr)
                if eval {
                    car = res
                } else {
                    result = res
                }

            case let .Symbol(s):
                result = try resolve(s)

            default:
                result = car
            }
        }

        // remove any created frame
        while cur < stack.count { _ = stack.popLast() }

        return result!
    }

    var stack: [[String: Datum]] = [[:]]

    init() throws {
        for datum in builtin {
            switch datum {
            case let .Procedure(name, _):
                define_var(name, datum)
            case let .SpecialForm(name, _):
                define_var(name, datum)
            default:
                throw Exception.General("Internal error: not a builtin procedure or syntax form\(datum)")
            }
        }
    }

    func readLine(input: String) throws -> String {
        var car = try Node(input).car()
        var result: Datum = .Nil
        while case let .Pointer(first) = car {
            let cell = Cell(car: first.car, cdr: .Nil)
            result = try eval(cell.car)
//            if case .Undefined = result {} else {
//                print("=", result.display)
//            }
            guard stack.count == 1 else {
                print(stack)
                throw Exception.General("Stack error")
            }
            car = first.cdr
        }
        return result.display
    }
}

