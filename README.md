# PFFM20 120Hz Refresh Rule Override

Magisk module for OPPO PFFM20 / OP520F on ColorOS 12.1. It systemlessly overrides:

```text
/my_product/etc/refresh_rate_config.xml
```

The install helper generates the override XML from the device's current `/my_product/etc/refresh_rate_config.xml`. It changes the fourth slot of each `rateId`, which corresponds to the 120Hz setting mode in this firmware's XML format. It also sets `disableViewOverride="true"` on every `<item>` rule so app/window-level refresh-rate requests cannot override the XML rule back to 60Hz. The global `<config>` row is rewritten to disable OPPO's input-method low-rate policy:

```xml
<config enableRateOverride="true" inputMethodLowRate="false" enableFodHighRate="true" />
```

Example:

```xml
rateId="2-2-2-2" -> rateId="2-2-2-3"
rateId="0-0-0-0" -> rateId="0-0-0-3"
```

This keeps auto / 90Hz / 60Hz behavior untouched while preventing OPPO's app-specific rules and input-method low-rate policy from mapping the 120Hz mode back to 60Hz.

## Runtime Mounting

The runtime mount follows the same pattern used by the PFFM20 temperature spoof module:

1. `mount-refresh-config.sh` prepares state storage and shared mount helpers.
2. `post-fs-data.sh` applies the tmpfs bind mount early so OPPO's display services load the modified XML.
3. `service.sh` runs at late_start service time and reapplies the same mount as a fallback, first cleaning any previous tmpfs source mount.
4. The mount source is created under:

```text
/dev/pffm20_120hz_rr_override/ctx_system_file
```

5. It copies the modified XML into that tmpfs source.
6. It sets the source file context to match the target:

```text
u:object_r:system_file:s0
```

7. It bind-mounts the tmpfs file over:

```text
/my_product/etc/refresh_rate_config.xml
```

This avoids binding directly from `/data/adb/modules/...` to the target file.

## Layout

```text
module.prop
post-fs-data.sh
service.sh
mount-refresh-config.sh
files/refresh_rate_config.xml
tools/device-install.sh
tools/device-verify.sh
```

`files/refresh_rate_config.xml` is generated on the device during install and is not stored in the repository.

## Device Install

Stage the repository on the device and run the install helper:

```bash
adb -s 192.168.50.101:35555 shell su -c 'rm -rf /data/local/tmp/global120hz'
adb -s 192.168.50.101:35555 push . /data/local/tmp/global120hz
adb -s 192.168.50.101:35555 shell su -c 'sh /data/local/tmp/global120hz/tools/device-install.sh'
```

The installer backs up the original XML and writes the generated module copy to `/data/adb/modules/pffm20_120hz_rr_override/files/refresh_rate_config.xml`.

## Installed Module ID

```text
pffm20_120hz_rr_override
```

## Disable

```bash
adb -s 192.168.50.101:35555 shell su -c 'touch /data/adb/modules/pffm20_120hz_rr_override/disable'
adb -s 192.168.50.101:35555 reboot
```
