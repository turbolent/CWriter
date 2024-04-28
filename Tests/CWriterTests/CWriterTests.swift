import XCTest
import CWriter

class CWriterTests: XCTestCase {

    public func testIncludeWithQuotes() throws {
        var writer = Writer()

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
        var writer = Writer()

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
        var writer = Writer()

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
        var writer = Writer()

        Braced {
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
        var writer = Writer()

        Braced {
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
        var writer = Writer()

        Function(
            returnType: .Raw("int"),
            identifier: "foo",
            parameters: [
                .init(identifier: "bar", type: .Raw("char")),
                .init(identifier: "baz", type: .Raw("void"))
            ]
        ) {
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
        var writer = Writer()

        Function(
            returnType: .Raw("int"),
            identifier: "foo",
            parameters: [
                .init(identifier: "bar", type: .Raw("char")),
                .init(identifier: "baz", type: .Raw("void"))
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
        var writer = Writer()

        Function(
            returnType: .Raw("int"),
            identifier: "foo"
        ).write(to: &writer)

        XCTAssertEqual(
            """
            int foo();

            """,
            writer.stream
        )
    }

    public func testFunctionWithVoidParameter() throws {
        var writer = Writer()

        Function(
            returnType: .Raw("int"),
            identifier: "foo",
            parameters: [
                .init(type: .Raw("void"))
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
        var writer = Writer()

        Typedef(
            identifier: "Foo",
            type: .Declaration(TypeDeclaration(
                typeSpecifier: .Struct("Bar")
            ))
        ).write(to: &writer)

        XCTAssertEqual(
            """
            typedef struct Bar Foo;

            """,
            writer.stream
        )
    }

    public func testStructWithoutFields() throws {
        var writer = Writer()

        Struct(identifier: "Foo")
            .write(to: &writer)

        XCTAssertEqual(
            """
            struct Foo {};

            """,
            writer.stream
        )
    }

    public func testStructWithFields() throws {
        var writer = Writer()

        Struct(identifier: "Foo") {
            Field(identifier: "foo", type: .Raw("int"))
            Field(
                identifier: "bar",
                type: .Declaration(TypeDeclaration(
                    typeSpecifier: .Name("char"),
                    declarators: [.Pointer(isConst: false)]
                ))
            )
        }.write(to: &writer)

        XCTAssertEqual(
            """
            struct Foo {
                int foo;
                char *bar;
            };

            """,
            writer.stream
        )
    }

    public func testAttribute() throws {
        var writer = Writer()

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
        var writer = Writer()

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
        var writer = Writer()

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

    public func testConcat() throws {
        var writer = Writer()

        Indented {
            Concat {
                Raw("a")
                Newline
            }
            Concat {
                Raw("b")
                Newline
            }
            Concat {
                Raw("c")
                Raw("d")
            }
        }.write(to: &writer)

        XCTAssertEqual(
            """
                a
                b
                cd
            """,
            writer.stream
        )
    }

    public func testTypeDeclarationNameNoIdentifier() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Name("int")
        ).write(identifier: nil, to: &result)

        XCTAssertEqual("int", result)
    }

    public func testTypeDeclarationNameWithIdentifier() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Name("int")
        ).write(identifier: "foo", to: &result)

        XCTAssertEqual("int foo", result)
    }

    public func testTypeDeclarationPointerNoIdentifier() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Name("int"),
            declarators: [.Pointer(isConst: false)]
        ).write(identifier: nil, to: &result)

        XCTAssertEqual("int*", result)
    }

    public func testTypeDeclarationPointerWithIdentifier() throws {
        var result = ""

         TypeDeclaration(
            typeSpecifier: .Name("int"),
            declarators: [.Pointer(isConst: false)]
        ).write(identifier: "foo", to: &result)

        XCTAssertEqual("int *foo", result)
    }

    public func testTypeDeclarationStructNoIdentifier() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Struct("X")
        ).write(identifier: nil, to: &result)

        XCTAssertEqual("struct X", result)
    }

    public func testTypeDeclarationStructWithIdentifier() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Struct("X")
        ).write(identifier: "foo", to: &result)

        XCTAssertEqual("struct X foo", result)
    }

     public func testBuild() throws {
        var writer = Writer()

        build {
            Include(file: "foo", style: .Quotes)
            Include(file: "bar", style: .AngularBrackets)
            Struct(identifier: "Foo")
            Function(
                returnType: .Raw("int"),
                identifier: "foo"
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
            var writer = Writer()
            build {
                Include(file: "foo", style: .Quotes)
                Include(file: "bar", style: .AngularBrackets)
                if writeFoo {
                    Struct(identifier: "Foo")
                }
                Function(
                    returnType: .Raw("int"),
                    identifier: "foo"
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
            var writer = Writer()
            build {
                Include(file: "foo", style: .Quotes)
                Include(file: "bar", style: .AngularBrackets)
                if writeFoo {
                    Struct(identifier: "Foo")
                } else {
                    Struct(identifier: "Bar")
                }
                Function(
                    returnType: .Raw("int"),
                    identifier: "foo"
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

    public func testLineLineComment() throws {
        var writer = Writer()

        LineComment("this is a comment.\nit spans multiple lines")
            .write(to: &writer)

        XCTAssertEqual(
            """
            // this is a comment.
            // it spans multiple lines

            """,
            writer.stream
        )
    }

    public func testTypeDeclarationMultipleDeclarators() throws {
        var result = ""

        TypeDeclaration(
            typeSpecifier: .Name("int"),
            declarators: [
                .Pointer(isConst: true),
                .Array(size: 2),
                .Array(size: 3)
            ]
        ).write(identifier: "test", to: &result)

        XCTAssertEqual("int (*const test)[2][3]", result)
    }
}
