using JuliaLangProjectHarness
using ScienceResearch

@testset "harness profile" begin
    @test isdefined(JuliaLangProjectHarness, :assert_julia_project_harness_test_profile_clean)
    profile = assert_julia_project_harness_test_profile_clean(
        pkgdir(ScienceResearch);
        advice_io = nothing,
    )
    @test profile isa JuliaLangProjectHarness.JuliaVerificationProfile
end
