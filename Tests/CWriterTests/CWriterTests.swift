import XCTest
@testable import CWriter

class CWriterTests: XCTestCase {

    public func testIncludeWithQuotes() throws {
        var writer = CWriter()

        Include(file: "foo", style: .Quotes)
            .write(to: &writer)

        XCTAssertEqual(
            """
            #include "foo"

            """,
            writer.stream
        )
    }

    public func testIncludeWithAngularBrackets() throws {
        var writer = CWriter()

        Include(file: "foo", style: .AngularBrackets)
            .write(to: &writer)

        XCTAssertEqual(
            """
            #include <foo>

            """,
            writer.stream
        )
    }

    public func testIndented() throws {
        var writer = CWriter()

        Indented {
            Include(file: "foo", style: .Quotes)
        }.write(to: &writer)

        XCTAssertEqual(
            """
                #include "foo"

            """,
            writer.stream
        )
    }

    public func testBraced() throws {
        var writer = CWriter()

        Braced {
            Newline
            Include(file: "foo", style: .Quotes)
        }.write(to: &writer)

        XCTAssertEqual(
            """
            {
                #include "foo"
            }
            """,
            writer.stream
        )
    }

    public func testNewline() throws {
        var writer = CWriter()

        Braced {
            Newline
            Include(file: "foo", style: .Quotes)
            Include(file: "bar", style: .Quotes)
        }.write(to: &writer)

        XCTAssertEqual(
            """
            {
                #include "foo"
                #include "bar"
            }
            """,
            writer.stream
        )
    }

    public func testFunctionWithParametersAndBody() throws {
        var writer = CWriter()

        Function(
            returnType: .Nominal("int"),
            name: "foo",
            parameters: [
                .init(name: "bar", type: .Nominal("char")),
                .init(name: "baz", type: .Nominal("void"))
            ]
        ) {
            Newline
            Include(file: "foo", style: .Quotes)
        }.write(to: &writer)

        XCTAssertEqual(
            """
            int foo(char bar, void baz) {
                #include "foo"
            }

            """,
            writer.stream
        )
    }

    public func testFunctionWithoutBody() throws {
        var writer = CWriter()

        Function(
            returnType: .Nominal("int"),
            name: "foo",
            parameters: [
                .init(name: "bar", type: .Nominal("char")),
                .init(name: "baz", type: .Nominal("void"))
            ]
        ).write(to: &writer)

        XCTAssertEqual(
            """
            int foo(char bar, void baz);

            """,
            writer.stream
        )
    }

    public func testFunctionWithoutParameters() throws {
        var writer = CWriter()

        Function(
            returnType: .Nominal("int"),
            name: "foo"
        ).write(to: &writer)

        XCTAssertEqual(
            """
            int foo();

            """,
            writer.stream
        )
    }

    public func testFunctionWithVoidParameter() throws {
        var writer = CWriter()

        Function(
            returnType: .Nominal("int"),
            name: "foo",
            parameters: [
                .init(type: .Nominal("void"))
            ]
        ).write(to: &writer)

        XCTAssertEqual(
            """
            int foo(void);

            """,
            writer.stream
        )
    }

    public func testTypedef() throws {
        var writer = CWriter()

        Typedef(name: "Foo", type: .Struct("Bar"))
            .write(to: &writer)

        XCTAssertEqual(
            """
            typedef struct Bar Foo;

            """,
            writer.stream
        )
    }

    public func testStructWithoutFields() throws {
        var writer = CWriter()

        Struct(name: "Foo")
            .write(to: &writer)

        XCTAssertEqual(
            """
            struct Foo {};

            """,
            writer.stream
        )
    }

    public func testStructWithFields() throws {
        var writer = CWriter()

        Struct(name: "Foo") {
            Field(name: "foo", type: .Nominal("int"))
            Field(name: "bar", type: .Pointer(.Nominal("char")))
        }.write(to: &writer)

        XCTAssertEqual(
            """
            struct Foo {
                int foo;
                char* bar;
            };

            """,
            writer.stream
        )
    }

    public func testAttribute() throws {
        var writer = CWriter()

        Attribute(contents: "foo")
            .write(to: &writer)

        XCTAssertEqual(
            """
            __attribute__(foo)
            """,
            writer.stream
        )
    }

    public func testImportAttributeWithoutModuleName() throws {
        var writer = CWriter()

        ImportAttribute(importName: "foo")
            .write(to: &writer)

        XCTAssertEqual(
            """
            __attribute__(__import_name__("foo"))
            """,
            writer.stream
        )
    }

    public func testImportAttributeWithModuleName() throws {
        var writer = CWriter()

        ImportAttribute(
            importName: "foo",
            moduleName: "bar"
        ).write(to: &writer)

        XCTAssertEqual(
            """
            __attribute__(__import_name__("foo"), __module_name__("bar"))
            """,
            writer.stream
        )
    }

    public func testTypeNominal() throws {
        var result = ""

        Type.Nominal("int").write(to: &result)

        XCTAssertEqual("int", result)
    }

    public func testTypePointer() throws {
        var result = ""

        Type.Pointer(.Nominal("int")).write(to: &result)

        XCTAssertEqual("int*", result)
    }

    public func testTypeStruct() throws {
        var result = ""

        Type.Struct("X").write(to: &result)

        XCTAssertEqual("struct X", result)
    }

     public func testBuild() throws {
        var writer = CWriter()

        build {
            Include(file: "foo", style: .Quotes)
            Include(file: "bar", style: .AngularBrackets)
            Struct(name: "Foo")
            Function(
                returnType: .Nominal("int"),
                name: "foo"
            )
        }.forEach { $0.write(to: &writer) }

        XCTAssertEqual(
            """
            #include "foo"
            #include <bar>
            struct Foo {};
            int foo();

            """,
            writer.stream
        )
    }

    public func testBuildIf() throws {

        func testBuild(writeFoo: Bool) -> String {
            var writer = CWriter(stream: "")
            build {
                Include(file: "foo", style: .Quotes)
                Include(file: "bar", style: .AngularBrackets)
                if writeFoo {
                    Struct(name: "Foo")
                }
                Function(
                    returnType: .Nominal("int"),
                    name: "foo"
                )
            }.forEach { $0.write(to: &writer) }
            return writer.stream
        }

        XCTAssertEqual(
            """
            #include "foo"
            #include <bar>
            struct Foo {};
            int foo();

            """,
            testBuild(writeFoo: true)
        )

        XCTAssertEqual(
            """
            #include "foo"
            #include <bar>
            int foo();

            """,
            testBuild(writeFoo: false)
        )
    }

    public func testBuildIfElse() throws {


        func testBuild(writeFoo: Bool) -> String {
            var writer = CWriter(stream: "")
            build {
                Include(file: "foo", style: .Quotes)
                Include(file: "bar", style: .AngularBrackets)
                if writeFoo {
                    Struct(name: "Foo")
                } else {
                    Struct(name: "Bar")
                }
                Function(
                    returnType: .Nominal("int"),
                    name: "foo"
                )
            }.forEach { $0.write(to: &writer) }
            return writer.stream
        }

        XCTAssertEqual(
            """
            #include "foo"
            #include <bar>
            struct Foo {};
            int foo();

            """,
            testBuild(writeFoo: true)
        )

        XCTAssertEqual(
            """
            #include "foo"
            #include <bar>
            struct Bar {};
            int foo();

            """,
            testBuild(writeFoo: false)
        )
    }
}
