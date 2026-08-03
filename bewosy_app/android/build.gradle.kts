allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some plugin AARs (fluttertoast, package_info_plus, share_plus) still ship with an
// old compileSdk while pulling in newer androidx transitive deps that require 34+.
// Force every Android subproject (including plugin modules) to compile against a
// modern SDK so the AAR metadata check doesn't fail the build. Must be registered
// before evaluationDependsOn(":app") below forces :app to evaluate early, otherwise
// Gradle rejects the afterEvaluate hook on an already-evaluated project.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
