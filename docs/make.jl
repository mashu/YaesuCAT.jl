using Documenter

# When building docs, include the package source directly
include(joinpath(@__DIR__, "..", "src", "YaesuCAT.jl"))
using .YaesuCAT

makedocs(
    sitename = "YaesuCAT.jl",
    modules  = [YaesuCAT],
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages = [
        "Home"          => "index.md",
        "Getting Started" => "guide.md",
        "CW Keying"    => "cw.md",
        "API Reference" => "api.md",
    ],
    # Build without git remote (e.g. local or when origin is not set)
    remotes = nothing,
    # Allow docstrings that are not included in @docs blocks (e.g. internal helpers)
    checkdocs = :none,
)

# Deploy to GitHub Pages when DOCUMENTER_KEY is set (e.g. in mashu/YaesuCAT.jl CI)
if haskey(ENV, "DOCUMENTER_KEY")
    deploydocs(
        repo = "github.com/mashu/YaesuCAT.jl.git",
        devurl = "dev",
        versions = ["stable" => "v^", "dev" => "dev"],
    )
end
