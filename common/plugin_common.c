#include "plugin_common.h"

void NotifyStatic(const char *IconUri, const char *text)
{
    OrbisNotificationRequest buffer;
    memset(&buffer, 0, sizeof(buffer));
    buffer.type = NotificationRequest;
    buffer.unk3 = 0;
    buffer.useIconImageUri = 1;
    buffer.targetId = -1;
    snprintf(buffer.message, sizeof(buffer.message), "%s", text);
    snprintf(buffer.iconUri, sizeof(buffer.iconUri), "%s", IconUri);
    sceKernelSendNotificationRequest(0, &buffer, sizeof(buffer), 0);
}

void Notify(const char *IconUri, const char *fmt, ...)
{
    OrbisNotificationRequest buffer;
    va_list args;

    memset(&buffer, 0, sizeof(buffer));
    va_start(args, fmt);
    vsnprintf(buffer.message, sizeof(buffer.message), fmt, args);
    va_end(args);

    buffer.type = NotificationRequest;
    buffer.unk3 = 0;
    buffer.useIconImageUri = 1;
    buffer.targetId = -1;
    snprintf(buffer.iconUri, sizeof(buffer.iconUri), "%s", IconUri);
    sceKernelSendNotificationRequest(0, &buffer, sizeof(buffer), 0);
}
