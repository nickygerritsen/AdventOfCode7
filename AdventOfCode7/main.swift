//
//  main.swift
//  AdventOfCode7
//
//  Created by Nicky Gerritsen on 20-12-15.
//  Copyright © 2015 Nicky Gerritsen. All rights reserved.
//

import Foundation

enum Source {
    case Vertex(String)
    case Constant(UInt16)

    func valueForGraph(graph: Graph) -> UInt16 {
        switch self {
        case let .Vertex(vertex):
            guard let v = graph.vertices[vertex] else { fatalError("Unknown source 1 vertex") }
            guard let val = v.value else { fatalError("Vertex 1 does not have a value yet") }
            return val
        case let .Constant(val):
            return val
        }
    }

    var vertex: String? {
        switch self {
        case let .Vertex(v):
            return v
        case .Constant(_):
            return nil
        }
    }

    static func parse(s: String) -> Source {
        if let i = UInt16(s) {
            return .Constant(i)
        } else {
            return .Vertex(s)
        }
    }
}

enum Operation {
    case Assign(Source)
    case And(Source, Source)
    case Or(Source, Source)
    case Not(Source)
    case LeftShift(Source, UInt16)
    case RightShift(Source, UInt16)

    func applytoGraph(graph: Graph, vertex: String) {
        guard let v = graph.vertices[vertex] else { fatalError("Unknown target vertex") }
        if let curVal = v.value { fatalError("Vertex \(vertex) already has a value \(curVal), can not set new value") }
        switch self {
        case let .Assign(source1):
            v.value = source1.valueForGraph(graph)
        case let .And(source1, source2):
            v.value = source1.valueForGraph(graph) & source2.valueForGraph(graph)
        case let .Or(source1, source2):
            v.value = source1.valueForGraph(graph) | source2.valueForGraph(graph)
        case let .Not(source1):
            v.value = ~source1.valueForGraph(graph)
        case let .LeftShift(source1, bits):
            v.value = source1.valueForGraph(graph) << bits
        case let .RightShift(source1, bits):
            v.value = source1.valueForGraph(graph) >> bits
        }
    }

    static func parseOperation(input: String) -> Operation {
        if let and = input.rangeOfString(" AND ") {
            let before = input.substringToIndex(and.startIndex)
            let after = input.substringFromIndex(and.endIndex)
            return .And(Source.parse(before), Source.parse(after))
        } else if let or = input.rangeOfString(" OR ") {
            let before = input.substringToIndex(or.startIndex)
            let after = input.substringFromIndex(or.endIndex)
            return .Or(Source.parse(before), Source.parse(after))
        } else if let not = input.rangeOfString("NOT ") {
            let after = input.substringFromIndex(not.endIndex)
            return .Not(Source.parse(after))
        } else if let lshift = input.rangeOfString(" LSHIFT ") {
            let before = input.substringToIndex(lshift.startIndex)
            let after = input.substringFromIndex(lshift.endIndex)
            guard let afterInt = UInt16(after) else { fatalError("Can not parse LSHIFT integer") }
            return .LeftShift(Source.parse(before), afterInt)
        } else if let rshift = input.rangeOfString(" RSHIFT ") {
            let before = input.substringToIndex(rshift.startIndex)
            let after = input.substringFromIndex(rshift.endIndex)
            guard let afterInt = UInt16(after) else { fatalError("Can not parse RSHIFT integer") }
            return .RightShift(Source.parse(before), afterInt)
        } else {
            return .Assign(Source.parse(input))
        }
    }

    var sourceVertices: [String] {
        var vertices: [String] = []

        switch self {
        case let .Assign(s):
            if let v = s.vertex {
                vertices.append(v)
            }
        case let .And(s1, s2):
            if let v = s1.vertex {
                vertices.append(v)
            }
            if let v = s2.vertex {
                vertices.append(v)
            }
        case let .Or(s1, s2):
            if let v = s1.vertex {
                vertices.append(v)
            }
            if let v = s2.vertex {
                vertices.append(v)
            }
        case let .Not(s):
            if let v = s.vertex {
                vertices.append(v)
            }
        case let .LeftShift(s, _):
            if let v = s.vertex {
                vertices.append(v)
            }
        case let .RightShift(s, _):
            if let v = s.vertex {
                vertices.append(v)
            }
        }

        return vertices
    }
}

class Vertex {
    var idx: String
    var outgoing: Set<String>
    var incoming: Set<String>
    var operations: [Operation]
    var value: UInt16?

    init(idx: String) {
        self.idx = idx
        self.outgoing = []
        self.incoming = []
        self.operations = []
    }
}

extension Vertex: Equatable {}

func ==(lhs: Vertex, rhs: Vertex) -> Bool {
    return lhs.idx == rhs.idx
}

extension Vertex: Hashable {
    var hashValue: Int {
        return self.idx.hashValue
    }
}

class Graph {
    var vertices: [String: Vertex]

    init() {
        self.vertices = [:]
    }

    func addVertexIfNotExists(idx: String) {
        if let _ = self.vertices[idx] {
            return
        }

        self.vertices[idx] = Vertex(idx: idx)
    }

    func addOperation(operation: Operation, target: String) {
        self.addVertexIfNotExists(target)

        self.vertices[target]?.operations.append(operation)

        let sourceVertices = operation.sourceVertices
        for v in sourceVertices {
            self.addVertexIfNotExists(v)
            self.vertices[target]?.incoming.insert(v)
            self.vertices[v]?.outgoing.insert(target)
        }
    }
}

extension Graph {
    func topologicalOrder() -> [Vertex] {
        var L: [Vertex] = []
        var S: Set<Vertex> = Set(vertices.values.filter { $0.incoming.count == 0 })

        while S.count > 0 {
            guard let n = S.first else { fatalError("No more nodes in S") }
            S.remove(n)
            L.append(n)

            for midx in n.outgoing {
                guard let m = self.vertices[midx] else { fatalError("Can not find vertex") }
                n.outgoing.remove(m.idx)
                m.incoming.remove(n.idx)

                if m.incoming.count == 0 {
                    S.insert(m)
                }
            }
        }

        let withEdges = vertices.values.filter { $0.incoming.count > 0 || $0.outgoing.count > 0 }
        if withEdges.count > 0 {
            fatalError("Some vertex still has some edges")
        }
        
        return L
    }
}

func buildGraph(lines: [String]) -> Graph {
    let graph = Graph()

    for line in lines {
        // We need to split the line on " -> "
        if let arrow = line.rangeOfString(" -> ") {
            let beforeArrow = line.substringToIndex(arrow.startIndex)
            let afterArrow = line.substringFromIndex(arrow.endIndex)

            let operation = Operation.parseOperation(beforeArrow)
            graph.addOperation(operation, target: afterArrow)
        } else {
            fatalError("No arrow :(")
        }
    }

    return graph
}

func getFinalValueInGraph(graph: Graph, vertex: String) -> UInt16? {
    let topo = graph.topologicalOrder()

    for vertex in topo {
        for op in vertex.operations {
            op.applytoGraph(graph, vertex: vertex.idx)
        }
    }

    return graph.vertices[vertex]?.value
}

func go1(lines: [String]) {
    let graph = buildGraph(lines)

    guard let v = getFinalValueInGraph(graph, vertex: "a") else { fatalError("Can not get value of a") }

    print(v)
}


func go2(lines: [String]) {
    let graph = buildGraph(lines)

    guard let v = getFinalValueInGraph(graph, vertex: "a") else { fatalError("Can not get value of a") }

    let graph2 = buildGraph(lines)
    guard let vertex = graph2.vertices["b"] else { fatalError("Can not find vertex b") }

    guard vertex.operations.count == 1 else { fatalError("Too many operations") }
    vertex.operations[0] = .Assign(.Constant(v))

    guard let v2 = getFinalValueInGraph(graph2, vertex: "a") else { fatalError("Can not get value of a") }

    print(v2)
}


do {
    guard Process.argc >= 2 else { fatalError("Not enough arguments") }
    let input = Process.arguments[1]
    let contents = try String(contentsOfFile: input, encoding: NSUTF8StringEncoding)

    let lines = contents.characters.split("\n").map(String.init)

    autoreleasepool {
        go1(lines)
    }
    autoreleasepool {
        go2(lines)
    }
} catch (let e) {
    print(e)
}