#!/system/bin/sh
echo "### module files"
ls -laZ /data/adb/modules/pffm20_120hz_rr_override /data/adb/modules/pffm20_120hz_rr_override/files 2>&1
echo "### runtime source"
ls -laZ /dev/pffm20_120hz_rr_override /dev/pffm20_120hz_rr_override/ctx_system_file 2>&1
echo "### mountinfo"
grep '/my_product/etc/refresh_rate_config.xml' /proc/self/mountinfo 2>/dev/null || true
grep '/dev/pffm20_120hz_rr_override' /proc/self/mountinfo 2>/dev/null || true
echo "### contexts"
ls -laZ /my_product/etc/refresh_rate_config.xml /dev/pffm20_120hz_rr_override/ctx_system_file/refresh_rate_config.xml 2>&1
echo "### samples"
grep com.ss.android.ugc.aweme /my_product/etc/refresh_rate_config.xml | head -2
grep com.tencent.mm /my_product/etc/refresh_rate_config.xml | grep rateId | head -3
echo "### log"
tail -30 /data/adb/pffm20_120hz_rr_override/module.log 2>/dev/null || true
