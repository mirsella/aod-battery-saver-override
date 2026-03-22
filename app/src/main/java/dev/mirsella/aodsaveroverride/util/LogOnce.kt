package dev.mirsella.aodsaveroverride.util

import java.util.concurrent.ConcurrentHashMap

object LogOnce {
    private val loggedKeys = ConcurrentHashMap.newKeySet<String>()

    fun log(
        logger: (priority: Int, message: String, throwable: Throwable?) -> Unit,
        priority: Int,
        key: String,
        message: String,
        throwable: Throwable? = null,
    ) {
        if (loggedKeys.add(key)) {
            logger(priority, message, throwable)
        }
    }
}
