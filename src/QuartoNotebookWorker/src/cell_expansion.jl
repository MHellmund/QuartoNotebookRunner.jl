"""
    struct Cell
    Cell(content; code = nothing, options = Dict())

`content` is either a callable object, which should have a 0-argument method
which, when called, represents the evaluation of the cell, or any other
non-callable object, which will simply be treated as the output value of the
cell. Should you wish to use a callable object as the output of a cell, rather
than calling it, you can wrap it in a `Returns` object.

`code` is the mock source code of the cell, and is not parsed or evaluated, but
will be rendered in the final output generated by `quarto`. When `code` is not
provided then the code block is hidden with `echo: false`. `options` represents
the cell options for the mock cell and will impact the rendering of the final
output.
"""
struct Cell
    thunk::Base.Callable
    code::String
    options::Dict{String,Any}

    function Cell(object; code::Union{String,Nothing} = nothing, options::Dict = Dict())
        thunk = _make_thunk(object)
        if isnothing(code)
            options["echo"] = false
            code = ""
        end
        new(thunk, code, options)
    end
end

_make_thunk(c::Base.Callable) = c
# Returns is only available on 1.7 and upwards.
_make_thunk(other) = @static @isdefined(Returns) ? Returns(other) : () -> other

"""
    expand(object::T) -> Vector{Cell}

Define the vector of `Cell`s that an object of type `T` should expand to. See
`Cell` documentation for more details on `Cell` creation.
    
This function is meant to be extended by 3rd party packages using Julia's
package extension mechanism. For example, within the `Project.toml` of a package
called `ExamplePackage` add the following:

```toml
[weakdeps]
QuartoNotebookWorker = "38328d9c-a911-4051-bc06-3f7f556ffeda"

[extensions]
ExamplePackageQuartoNotebookWorkerExt = "QuartoNotebookWorker"
```

Then create a file `ext/ExamplePackageQuartoNotebookWorkerExt.jl` with the the contents

```julia
module ExamplePackageQuartoNotebookWorkerExt

import ExamplePackage
import QuartoNotebookWorker

function QuartoNotebookWorker.expand(obj::ExamplePackage.ExampleType)
    return [
        QuartoNotebookWorker.Cell("This is the cell result."; code = "# Mock code goes here."),
        QuartoNotebookWorker.Cell("This is a second cell."),
    ]
end

end
```
"""
expand(@nospecialize(_)) = nothing

struct CellExpansionError <: Exception
    message::String
end

_is_expanded(@nospecialize(_), ::Nothing) = false
_is_expanded(@nospecialize(_), ::Vector{Cell}) = true
function _is_expanded(@nospecialize(original), @nospecialize(result))
    throw(
        CellExpansionError(
            "invalid cell expansion result for `expand(::$(typeof(original)))`. Expected the result to be a `Vector{Cell}`, got `$(typeof(result))`.",
        ),
    )
end
