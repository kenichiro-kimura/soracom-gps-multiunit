pluginManagement {
    repositories {
        maven(url = "https://maven.google.com")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.10.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven(url = "https://maven.google.com")
        google()
        mavenCentral()
    }
}

rootProject.name = "soracom-gps-multiunit-android"
include(":app")
