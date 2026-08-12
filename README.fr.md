# SpacemiT K1 (RISC-V) — support board Android

Ce répertoire est la config device AOSP du SoC **SpacemiT K1** (8× X60,
`rv64gcv`, riscv64). Il supporte **deux boards** construites à partir du même
device `k1` :

| Board | `model` / `compatible` | Média bootloader | Média Android |
|---|---|---|---|
| **BananaPi BPI-F3** (Sinovoip) | `Banana Pi BPI-F3` / `bananapi,bpi-f3`, `spacemit,k1` | eMMC | eMMC |
| **MusePi Pro** (SpacemiT) | `SpacemiT MusePi Pro` / `spacemit,musepi-pro`, `spacemit,k1` | **SPI-NOR** | eMMC |

Les deux boards font tourner le même build Android et le même `Image` kernel ;
seuls l'**emplacement du bootloader** et le **device tree** diffèrent. Les images
Android partagées (`boot`/`vendor_boot`/`super`/`vbmeta`) embarquent un
**`dtb.img` multi-DTB** contenant les deux DTB de board, et U-Boot choisit la
bonne au boot via la variable d'env `adtb_idx` (voir plus bas).

## Un device, deux produits

Le device est `k1` ; les produits lunch vivent dans `bananapi_f3/` :

- `aosp_bananapi_f3` / `aosp_bananapi_f3_tablet`

Il n'y a **pas de produit MusePi Pro séparé**. La MusePi Pro boote les mêmes
images `aosp_bananapi_f3*` — la board est distinguée au boot par le
`product_name` de U-Boot, qui sélectionne la DTB (voir plus bas), pas par une
variante de build. (`PRODUCT_MODEL` affiche donc toujours « BananaPi F3 » ;
c'est attendu.)

## Device tree : parité + petits deltas

Les deux DTB sont buildées par le kernel
(`devices/spacemit/spacemit_soc/BUILD.bazel`, target `spacemit_k1x`) à partir des
sources dans `common/arch/riscv/boot/dts/spacemit/` :

- `k1-bananapi-f3.dtb`
- `k1-musepi-pro.dtb`

`k1-musepi-pro.dts` est en **parité complète avec la BananaPi-F3** — eMMC,
double Ethernet (RTL8211F RGMII), PMIC SpacemiT P1, PCIe, GPU (PowerVR Rogue),
pipeline HDMI, table OPP DVFS CPU, microSD et thermal zones identiques — avec
seulement ces **deltas** spécifiques à la board :

- `model` = `SpacemiT MusePi Pro`, `compatible` = `spacemit,musepi-pro`,
  `spacemit,k1` (vs `bananapi,bpi-f3`).
- **Mapping GPIO du hub USB3** : reset du hub sur `GPIO 123` (BananaPi :
  `GPIO 124`), plus un régulateur dédié pour le rail 5V du hub sur `GPIO 127` et
  un régulateur `USB30_VBUS` sur `GPIO 79`.

Tout le reste est partagé : le travail kernel/driver fait pour la BananaPi F3
s'applique tel quel à la MusePi Pro.

## Comment marche la sélection de board (multi-DTB + `adtb_idx`)

Le build empaquette les **deux** DTB dans une seule image multi-DTB, et U-Boot
en choisit une par index au boot :

- `build/tasks/dtimages.mk` lance `mkdtimg create` sur
  `k1-bananapi-f3.dtb` (index 0) + `k1-musepi-pro.dtb` (index 1) → `dtb.img`.
- `BOARD_INCLUDE_DTB_IN_BOOTIMG` embarque `dtb.img` dans `vendor_boot`.
- Au boot, le board file U-Boot (`board/spacemit/k1-x/k1x.c`) pose la variable
  d'env **`adtb_idx`** depuis `product_name` : `k1-x_MUSE-Pi-Pro` → `1`, sinon
  `0`. Elle est posée à chaque boot, donc elle survit à un env reflashé.
- `bootmeth_android` (`boot/image-fdt.c`) lit `${adtb_idx}` et passe au kernel
  cette DTB de `dtb.img`.

C'est pourquoi un seul jeu d'images Android boote les deux boards.

## Staging du bootloader (par board)

Android est identique pour les deux boards ; seuls les blobs bootloader et leur
média cible diffèrent. `Android.mk` stage les bootloaders prébuiltés produits par
l'arbre bootloaders (`release_android.sh`) :

- **BananaPi F3** — `vendor/spacemit/k1/bootloader/` → `PRODUCT_OUT/`
  (FSBL, OpenSBI `fw_dynamic`, U-Boot `u-boot.itb`, `env.bin`,
  `partition_android.json`, `bootinfo_emmc.bin`). Le bootloader vit en **eMMC**.
- **MusePi Pro** — `vendor/spacemit/musepi-pro/bootloader/` →
  `PRODUCT_OUT/musepi-pro/`. Même U-Boot K1 générique, mais avec
  `bootinfo_spinor.bin` et un layout MTD **`partition_nor.json`**, car le boot
  strap K1 de la Pro lit le bootloader depuis la **SPI-NOR**.

Si `vendor/spacemit/musepi-pro/bootloader/u-boot-release.itb` est absent, les
règles de staging MusePi Pro sont sautées (le build BananaPi n'est pas affecté).

## Flash

Utilise `flash_bpi_f3.sh` (copié dans `PRODUCT_OUT` à côté des images). Lance
d'abord `fastboot usb 0` sur la console U-Boot ; pour un premier setup, utilise
`--dfu` avec la board en mode BROM DFU.

```sh
# BananaPi F3 (défaut) — bootloader en eMMC, Android en eMMC
./flash_bpi_f3.sh                       # bootloader + Android
./flash_bpi_f3.sh --android             # Android seul
./flash_bpi_f3.sh --dfu --wipe          # premier DFU, userdata propre

# MusePi Pro — bootloader en SPI-NOR, Android en eMMC
./flash_bpi_f3.sh --board musepi-pro            # bootloader + Android
./flash_bpi_f3.sh --board musepi-pro --android  # Android seul (NOR intacte)
./flash_bpi_f3.sh --board musepi-pro --dfu      # premier DFU
```

Ce que change `--board musepi-pro` :

- Le bootloader est lu depuis `PRODUCT_OUT/musepi-pro/` au lieu de `PRODUCT_OUT/`.
- Le bootloader est écrit en **SPI-NOR** : le script fait d'abord
  `fastboot flash mtd partition_nor.json` (ce qui route les partitions nommées
  suivantes vers le device MTD NOR), puis écrit `bootinfo_spinor.bin`, FSBL,
  `env`, OpenSBI et U-Boot en NOR.
- Android (`boot`/`vendor_boot`/`super`/`vbmeta`/`dtbo`, slots A/B) est toujours
  flashé en **eMMC**, exactement comme sur la BananaPi F3.

Le chemin BananaPi F3 écrit au contraire le bootloader en eMMC
(`flash fsbl/env/opensbi/uboot`, plus `bootinfo_emmc.bin`).

Voir `flash_bpi_f3.sh --help` pour tous les modes et `--no-avb` (bring-up).

## Voir aussi

- `flash_bpi_f3.sh` — l'outil de flash (les deux boards).
- `profiling/README.md` — harness de profiling A/B kernel (actuellement exercé
  sur la BananaPi F3 ; board-agnostique via la DTB sélectionnée par `adtb_idx`).
- `README.md` — version anglaise de ce document.
