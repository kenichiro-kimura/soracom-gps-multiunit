buildscript {
    dependencies {
        // AGP の built-in Kotlin と Compose compiler を同じバージョンに揃える。
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
    }
}

plugins {
    id("com.android.application") version "9.4.1" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.20" apply false
}

