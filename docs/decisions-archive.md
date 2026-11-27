# Archived decisions

Decisions no longer in force, removed from [DECISIONS.md](DECISIONS.md) on 27/11/2026. Those
of 2026-10-07 and 2026-10-08 belong to the DIY pendant, all superseded by the decision of
2026-10-28 to buy Omi.

## 2026-10-07 Build instead of buying Omi

Omi costs $129 and is open source, but by default it goes through the phone and the cloud and
mostly keeps transcripts. We build it to spend less and have a custom device: offline
recording to microSD, raw audio kept, our own transcription pipeline.
Superseded by the decision of 2026-10-28 to buy Omi.

## 2026-10-07 Two boards: Super Mini on the bench, XIAO in the pendant

The Super Mini costs 3.90 € and has more pins, but its charging is uncertain, it has LEDs that
always draw current, and quality varies between batches. The XIAO has built-in charging,
documentation and consistent quality. Super Mini for firmware development, XIAO for the
wearable.
Superseded by the decision of 2026-10-07 on the XIAO Plus.

## 2026-10-07 503450 1000 mAh battery

For the same capacity it is the thinnest (about 5 mm against 6 for the 603048 and 8 for the
803040). In a pendant thickness matters more than footprint.

## 2026-10-07 microSD on an Adafruit 4682 clone module

A 3 V module with no regulator or level shifter, with the SDIO pins exposed: what a 3.3 V
ESP32-S3 needs. For the pin budget 1-bit SDIO will probably be used (see
`archive/ARCHITECTURE-diy.md #Budget dei pin`).

## 2026-10-07 Loose buttons from an assorted kit

The breakout board with 6×6 buttons is larger than the XIAO itself. An assorted kit covers
both the breadboard (6×6) and the case (3×6, 4×4).

## 2026-10-07 XIAO ESP32-S3 Plus both on the bench and in the pendant

The deciding criterion is the daily cycle: 16 hours of recording use about 800 mAh and must be
recharged in one night. The Plus charges at 100 mA (about 8 hours), the XIAO and the Sense at
50 mA (about 16). Rejected:

- **Sense**: equivalent microphone (SNR 64 against 65 dB for the ICS-43434), but it draws
  64.5 mA measured by Seeed while recording, so 16 hours do not fit in 1000 mAh, and it
  charges at 50 mA.
- **Standard XIAO**: costs only 0.49 € less and charges at 50 mA.
- **Super Mini on the bench**: saves about 4 €, but has less PSRAM, a different pinout and a
  charger that cannot be verified. With the same board on the bench, firmware and power
  measurements also hold for the pendant.
- **XIAO ESP32-C6**: modem-sleep at 30 mA, no advantage over the Plus, and no PSRAM.
- **nRF52840/nRF5340** (Omi, Friend): no WiFi, and 1.8 GB a day cannot be offloaded over BLE.

## 2026-10-07 A single ICS-43434 microphone, mono

Transcription does not use spatial separation, and stereo doubles the data and the SD power
draw. Three are bought: bench, pendant, and one to try the stereo pair if needed. The LR pin
allows adding the second one without extra pins.

## 2026-10-07 Standard branded microSD, not High Endurance

At 1.8 GB a day a 32 GB card goes through about 21 full write cycles a year, far below the
endurance of a branded TLC card. The PSRAM absorbs the write latency. High Endurance cards
cost twice as much (about 28 € against 10 € on Amazon) with no measurable benefit here.

## 2026-10-07 Acoustic mesh postponed to the case

The format depends on the diameter and position of the holes, which are decided in M4. It is
bought with the case materials.

## 2026-10-07 Fast charging as an option: TP4057 at 500 mA

The Plus charger at 100 mA is enough for one night, but not for top-ups: an hour on charge is
worth about 2 hours of recording. A TP4057 module wired directly to the battery charges it at
500 mA, that is 0.5C as per the stated standard charge: 800 mAh in about 1.6 hours of
constant current phase. The XIAO's USB stays for programming, and the two chargers must not be
powered at the same time. To be tried on the bench; M4 decides whether it goes into the case.
Rejected the TP4056 (footprint comparable to the XIAO and 1 A out of the box, that is 1C) and
the MCP73831 (only loose chips on AliExpress).

## 2026-10-08 Review with four reviewers: BOM corrections

INA226 instead of the INA219: 16 bits instead of 12, it measures the average and the
integrated charge over 16 hours better. Added bypass capacitors, spare JST connectors and
heat-shrink tubing, which were missing. The battery level needs no components: the Plus
exposes it on GPIO10. Dismissed the concern about the microphone at 16 kHz: low power mode
loses 1 dB of SNR and halves the power draw.

## 2026-10-08 DS3231 RTC on the I2C bus

For an all-day recorder the time of the files is essential, and without an RTC it is lost at
every power-off. The DS3231 mini (13.4 mm per side, backup battery on board, 5.59 €) uses the
I2C pins already planned, free in the pendant. Rejected the RV-3028 (only 14-28 € modules on
AliExpress) and reconstruction on the server side alone (gaps between a power-off and the
sync).

## 2026-10-08 Firmware: ESP-IDF, 5-minute files, buffer in internal RAM

ESP-IDF to have control over power saving, SD, encrypted NVS, flash encryption and OTA;
Arduino is built on top of it and takes control away. 5-minute files closed at every rotation
to survive power-offs; a 1-2 s buffer in internal RAM. Corrects the earlier idea of a
buffer of minutes in PSRAM: it is not needed for the SD latency and is lost if the battery
gives out.

## 2026-10-08 Configuration from its own WiFi network and a web page

The pendant turns on its own network only on request (long press, or first boot) and turns it
off after a few minutes: keeping it on whenever there is no connection would draw more than
recording. The network is protected by a per-unit password, with a captive portal, and the
same page on `pendant.local` at home. Rejected Espressif's Bluetooth provisioning (it needs
their app) and Web Bluetooth (it does not work on iPhone).

## 2026-10-08 WiFi and SD, not BLE streaming to the phone

Architecture confirmed: BLE streaming in the Omi style would give a much smaller device (a
XIAO nRF52840 Sense with 300 mAh, about 45-55 € per unit) and reuse of their software, but it
requires the phone nearby all day and gives up raw audio, which are the reasons for the
project.

## 2026-10-28 Audio to Nexus through the Omi app's live custom STT

The app sends the audio in real time to a WebSocket of ours, without writing an app and
without going through the Omi cloud (verified with the prototype, `ARCHITECTURE.md #Previous transport: Omi app and custom STT`).
Rejected: the "Realtime audio bytes" webhook (the Omi backend sends it, so the audio goes
through them), an iOS app of our own over Bluetooth (days of work and maintenance, to be
reconsidered if the Omi app becomes unreliable), a fixed Mac or Raspberry bridge (no live
audio on the move), self-hosting the Omi backend (more expensive than our own app and it does
not lead to Nexus).
Superseded by the decision of 2026-11-26 on our own iOS app, in use since 26/11.

## 2026-10-28 Omi settings to keep away from the cloud

Raw audio to Omi, cloud audio storage and automatic sync turned off, and no manual sync: these
are the four routes by which the audio would reach the Omi servers
(`ARCHITECTURE.md #Previous transport: Omi app and custom STT`).
Superseded by the decision of 2026-11-26 on our own iOS app: the Omi app stays only for the firmware, with the pendant forgotten.

## 2026-10-28 Offline audio: manual recovery

Audio recorded without the phone nearby stays in the app's buffer, which can only sync it to
Omi. For now it is recovered by hand with "Condividi registrazione". Rejected for now a PR to
Omi that would make the offline sync use the custom endpoint: days of work on their code, to
be reconsidered if offline audio turns out to be frequent in real use.
Superseded by the decision of 2026-11-26 on our own iOS app: the app reads the offline audio
(M9).

## 2026-10-29 Omi as it is, with two accepted limits

No fork of the app or the firmware, no app of our own. Two limits are accepted: when
disconnected the pause does not apply (the pendant records to its own storage), and offline
audio does not reach Nexus by itself. They are offset by turning the pendant off when it
should not record and by sharing by hand the offline recordings that matter. Rejected: an iOS
app of our own (background Bluetooth, protocol, maintenance, a developer account at $99 a
year, and it does not solve the pause, which the firmware decides); forking the app (huge,
tied to the Omi backend, changes by about 75 PRs a day); forking the firmware (feasible, the
signing key is in the repo, but a firmware that breaks Bluetooth bricks the pendant). The real
fixes are requested from Omi: issue #20174 and PR #23735.
Superseded by the decision of 2026-11-26 on our own iOS app.
