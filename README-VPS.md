# VPS مؤقت فوق GitHub Actions (Tailscale + LXD/LXC + pm2)

هاد الريبو فيه GitHub Action كتصايب ليك "VPS" حقيقي (Ubuntu كامل، root access) تقدر:

- تشعلو وقتما بغيتي (زر واحد فـ Actions)، ويخدم تقريبا 5 - 5.5 ساعة (هادشي حد GitHub، ماشي حد ديالي).
- تدخل ليه من الهاتف بـ **Tailscale** (بحال VPN خاص بينك وبين السيرفر).
- عندو صلاحيات **LXC/LXD** كاملة (containers).
- كتخدم فيه بوتات بـ **pm2**، ومنين تطفي وتشعل من بعد، البوتات **كيرجعو يخدمو وحدهم بحال ما كانو**.
- كل حاجة (ملفات، سكربتات، containers، إعدادات) كتتحفظ أوتوماتيكيا وكترجع فكل تشغيلة.

---

## ⚠️ تنبيه مهم قبل ما تبدا

الاستعمال هادا (Actions كـ VPS دائم، شبكة VPN بـ Tailscale، تشغيل بوتات بصفة مستمرة) **كيخالف شروط الاستخدام ديال GitHub** (Acceptable Use Policies)، لي كتمنع استعمال Actions كمنصة حوسبة عامة أو استضافة سيرفرات/بوتات دائمة أو VPN/proxy. GitHub عندها الحق توقف أو تبلوكي الحساب إلا شافت استعمال مبالغ فيه (24/7 مثلا، تعدين عملات، بوتات تجارية...).

هاد الحل مزيان **للتجربة والتطوير** (dev/testing) ماشي كحل production حقيقي. إلا بغيتي حاجة مضمونة ودائمة بلا مخاطرة، شري VPS رخيص حقيقي (Oracle Cloud Free Tier فيه Ubuntu مجاني للأبد، Hetzner، Contabo...) وديرها بحال ما بغيتي، بلا قيود.

كي تفهم هاد النقطة ومازال بغيتي نكملو، هاهو الشرح كامل 👇

---

## 1) الإعداد الأولاني (مرة وحدة)

### أ) صايب مفتاح Tailscale
1. سجل فـ [tailscale.com](https://tailscale.com) (مجاني).
2. سير لـ **Settings > Keys > Generate auth key**.
3. فعل **Reusable** (باش تخدم كل مرة تشعل فيها السيرفر) و **Ephemeral** (باش الجهاز يتمسح وحدو منين يطفى).
4. نسخ المفتاح (كيبدا بـ `tskey-...`).

### ب) زيد Secrets فالريبو
سير لـ **Settings > Secrets and variables > Actions > New repository secret** وزيد:

| اسم الـ Secret | القيمة |
|---|---|
| `TAILSCALE_AUTHKEY` | المفتاح لي صايبتي فـ Tailscale (خاصو، إجباري) |
| `SSH_PUBLIC_KEY` | المفتاح العمومي ديال SSH ديالك (اختياري، بغيتو باش تدخل بـ ssh عادي من غير Tailscale SSH) |

باش تصايب مفتاح SSH إلا مكانش عندك:
```bash
ssh-keygen -t ed25519 -C "phone-vps"
cat ~/.ssh/id_ed25519.pub   # هادشي كتدير فـ SSH_PUBLIC_KEY
```

---

## 2) كيفاش تشعل السيرفر

1. سير لـ **Actions** فوق الريبو.
2. اختار workflow اسمو **"VPS مؤقت (Tailscale + LXD + pm2)"**.
3. دوس **Run workflow**، اختار شحال من ساعة بغيتي (افتراضي 5.5) وكل شحال دقيقة يدير backup.
4. دوس **Run workflow** ✅.

من بعد شي دقيقة - جوج، حل اللوگ (logs) ديال الـ job وغادي تشوف فالآخر:
```
VPS واجد! (Tailscale hostname: gh-vps)
دخل ليه من أي جهاز فنفس ال-tailnet ديالك:
  tailscale ssh root@gh-vps
  ولا: ssh root@<IP tailscale>
```

---

## 3) كيفاش تدخل ليه من الهاتف بـ Tailscale

1. حمل تطبيق **Tailscale** من App Store / Google Play، ودخل بنفس الحساب لي صايبتي بيه المفتاح.
2. تأكد بلي التطبيق مفعل (VPN شغالة) فالهاتف.
3. حمل تطبيق SSH فالهاتف:
   - **Android**: Termux, JuiceSSH, Termius...
   - **iPhone**: Termius, Blink Shell...
4. دخل بـ:
   - Host: `gh-vps` (إلا كان MagicDNS مفعل فـ Tailscale admin) أو الـ IP لي بان فاللوگ (بحال `100.x.x.x`)
   - User: `root`
   - إلا صيفطتي `SSH_PUBLIC_KEY`: خدم بالمفتاح الخاص المطابق ليه.
   - أو جرب `tailscale ssh root@gh-vps` (Tailscale SSH، بلا حتى مفتاح، غير لازم يكون مفعل فـ ACL ديال tailnet ديالك - افتراضيا مفعل).

من دابا تقدر تخدم فالسيرفر بحال أي VPS عادي.

---

## 4) البوتات (تخدم، تطفى، ترجع بحالها)

خدم بـ **pm2** باش تشغل البوتات/السكربتات ديالك، PM2 كيحتفظ بلائحة العمليات وكيرجعها أوتوماتيكيا:

```bash
# مثال: تشغيل بوت بايثون
pm2 start bot.py --interpreter python3 --name my-bot

# مثال: تشغيل بوت node
pm2 start index.js --name my-bot

pm2 status       # شوف البوتات الخدامين
pm2 logs my-bot  # شوف اللوگ
pm2 save         # (كيتدار أوتوماتيكيا فكل checkpoint، ماخصكش تديرها يدويا)
```

منين تطفى السيرفر وتشعلو من بعد، الأكشن كيدير `pm2 resurrect` وحدو، وكل البوتات لي كانو خدامين كيرجعو يخدمو **بحال ما كانو بالضبط** بلا ما تعاود تشغلهم.

---

## 5) LXC / LXD (Containers)

السيرفر فيه LXD مصايب ومشعل، عندك صلاحيات كاملة:

```bash
lxc launch ubuntu:22.04 mycontainer
lxc list
lxc exec mycontainer -- bash
```

باش الـ container يرجع يخدم وحدو منين تشعل السيرفر من جديد، فعل `boot.autostart`:

```bash
lxc config set mycontainer boot.autostart true
```

كل container عندو `boot.autostart=true` غادي يبدا وحدو مباشرة منين تشعل السيرفر، بحال ما كان قبل ما يطفى.

---

## 6) كيفاش الحفظ خدام (تقنيا)

- كل `checkpoint_minutes` (افتراضي 15 دقيقة)، الأكشن كياخد نسخة من: `/root`, `/home`, `/etc/systemd/system`, `/var/snap/lxd/common/lxd` (كتقدر تبدلهم فـ `scripts/vps/persist-paths.txt`).
- النسخة كترفع لـ **GitHub Release** اسمو `vps-state` (asset: `backup.tar.gz`) فنفس الريبو.
- منين تشعل السيرفر من جديد، `bootstrap.sh` كيحمل هاد النسخة ويرجعها قبل ما يبدا أي حاجة.
- منين توقف الـ workflow (Cancel) ولا يوصل للوقت الأقصى، كيدير checkpoint أخير قبل ما يطفى.
- تقدر توقف السيرفر يدويا بلا ما تلغي الـ run: دخل ليه بـ SSH ودير `touch /tmp/stop-vps`.

⚠️ ملاحظة: GitHub Releases فيها حد أقصى 2GB للملف الواحد. إلا صاوبتي containers/بيانات كبيرة بزاف، نقص المسارات فـ `persist-paths.txt` أو استثني (`--exclude`) شي حاجة فـ `scripts/vps/backup.sh`.

---

## 7) الملفات المهمة فالريبو

```
.github/workflows/vps.yml       # الـ workflow الرئيسي
scripts/vps/bootstrap.sh        # تصايب tailscale + lxd + pm2 + استرجاع الحالة
scripts/vps/backup.sh           # حفظ الحالة (checkpoint)
scripts/vps/persist-paths.txt   # لائحة المسارات لي كتتحفظ
```
