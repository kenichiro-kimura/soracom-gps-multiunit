package com.gmail.kenichirokimura.gpsmultiunit.androidapp

data class SensorData(
    val lat: Double? = null,
    val lon: Double? = null,
    val temp: Double? = null,
    val humi: Double? = null,
    val x: Double? = null,
    val y: Double? = null,
    val z: Double? = null,
    val bat: Int? = null,
    val rs: Int? = null,
    val type: SendType,
) {
    fun toJsonString(): String = buildString {
        append("{")
        appendField("lat", lat)
        appendField("lon", lon)
        appendField("temp", temp)
        appendField("humi", humi)
        appendField("x", x)
        appendField("y", y)
        appendField("z", z)
        appendField("bat", bat)
        appendField("rs", rs)
        appendField("type", type.rawValue, trailingComma = false)
        append("}")
    }
}

enum class SendType(val rawValue: Int) {
    PERIODIC(0),
    MANUAL(1),
    ACCELERATION_ALERT(2),
}

private fun StringBuilder.appendField(key: String, value: Double?, trailingComma: Boolean = true) {
    append("\"").append(key).append("\":")
    append(value ?: "null")
    if (trailingComma) append(',')
}

private fun StringBuilder.appendField(key: String, value: Int?, trailingComma: Boolean = true) {
    append("\"").append(key).append("\":")
    append(value ?: "null")
    if (trailingComma) append(',')
}
