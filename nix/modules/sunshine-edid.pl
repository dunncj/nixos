#!/usr/bin/env perl
# Build a 128-byte EDID 1.3 for the synthetic Sunshine capture display.
# Descriptor slots (EDID 1.3 has exactly 4): DTD1 is the PREFERRED mode.
use strict; use warnings;

# ---- Detailed Timing Descriptor ------------------------------------------
# pclk in kHz; blanking/sync values are the usual CVT / CEA numbers.
sub dtd {
    my (%m) = @_;
    my $pc = int($m{pclk} / 10);                       # units of 10 kHz
    die "pixel clock $m{pclk} kHz out of EDID range" if $pc > 0xFFFF;
    my @b;
    $b[0]  = $pc & 0xFF;
    $b[1]  = ($pc >> 8) & 0xFF;
    $b[2]  = $m{hact} & 0xFF;
    $b[3]  = $m{hbl}  & 0xFF;
    $b[4]  = (($m{hact} >> 8) << 4) | (($m{hbl} >> 8) & 0x0F);
    $b[5]  = $m{vact} & 0xFF;
    $b[6]  = $m{vbl}  & 0xFF;
    $b[7]  = (($m{vact} >> 8) << 4) | (($m{vbl} >> 8) & 0x0F);
    $b[8]  = $m{hso} & 0xFF;
    $b[9]  = $m{hsw} & 0xFF;
    $b[10] = (($m{vso} & 0x0F) << 4) | ($m{vsw} & 0x0F);
    $b[11] = (($m{hso} >> 8) << 6) | ((($m{hsw} >> 8) & 0x3) << 4)
           | ((($m{vso} >> 4) & 0x3) << 2) | (($m{vsw} >> 4) & 0x3);
    $b[12] = $m{wmm} & 0xFF;
    $b[13] = $m{hmm} & 0xFF;
    $b[14] = (($m{wmm} >> 8) << 4) | (($m{hmm} >> 8) & 0x0F);
    $b[15] = 0; $b[16] = 0;                            # borders
    $b[17] = $m{flags};
    return @b;
}

sub name_desc {                                        # 0xFC monitor name
    my ($t) = @_;
    my @s = (0x00,0x00,0x00,0xFC,0x00, unpack('C*', $t), 0x0A);
    push @s, 0x20 while @s < 18;
    return @s;
}

# Physical size 697x392 mm (~31.5"): keeps DPI at 140 for 4K so Plasma does not
# silently pick 2x scaling, which would negate the extra pixels.
my ($WMM, $HMM) = (697, 392);
my $RB = 0x1A;   # digital separate sync, +hsync -vsync  (CVT reduced blanking)
my $CEA= 0x1E;   # digital separate sync, +hsync +vsync

my @modes = (
  # 2560x1440@60 CVT-RB  -- PREFERRED: RX 7600 games and encodes this comfortably
  { pclk=>241700, hact=>2560, hbl=>160, hso=>48,  hsw=>32, vact=>1440, vbl=>41, vso=>3, vsw=>5, flags=>$RB },
  # 3840x2160@60 CVT-RB  -- 533.25 MHz, lower link rate than the 594 MHz CEA timing
  { pclk=>533280, hact=>3840, hbl=>160, hso=>48,  hsw=>32, vact=>2160, vbl=>62, vso=>3, vsw=>5, flags=>$RB },
  # 1920x1080@60 CEA     -- the mode that exists today, kept as a fallback
  { pclk=>148500, hact=>1920, hbl=>280, hso=>88,  hsw=>44, vact=>1080, vbl=>45, vso=>4, vsw=>5, flags=>$CEA },
);

my @e = (0) x 128;
@e[0..7]   = (0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00);
@e[8,9]    = (0x31,0xD8);                 # "LNX"
@e[10,11]  = (0x00,0x00);                 # product code
@e[12..15] = (0,0,0,0);                   # serial
$e[16]     = 0;                           # week
$e[17]     = 2026 - 1990;                 # year
$e[18]     = 1; $e[19] = 3;               # EDID 1.3
$e[20]     = 0x80;                        # digital input
$e[21]     = int(($WMM + 5) / 10);        # max h image size, cm
$e[22]     = int(($HMM + 5) / 10);        # max v image size, cm
$e[23]     = 0x78;                        # gamma 2.2
$e[24]     = 0x0A;                        # RGB colour, preferred timing native,
                                          # bit0=0 => non-continuous freq, so no
                                          # range-limits descriptor is required
# sRGB chromaticity, byte-for-byte from the EDID already working on this GPU
@e[25..34] = (0xEE,0x91,0xA3,0x54,0x4C,0x99,0x26,0x0F,0x50,0x54);
@e[35..37] = (0x00,0x00,0x00);            # no established timings
@e[38..53] = (0x01,0x01) x 8;             # no standard timings

my $off = 54;
for my $m (@modes) { my @d = dtd(%$m, wmm=>$WMM, hmm=>$HMM); @e[$off .. $off+17] = @d; $off += 18; }
@e[$off .. $off+17] = name_desc("Virtual");

$e[126] = 0;                              # no extension blocks
my $sum = 0; $sum += $e[$_] for 0..125;   # checksum over 0..126, e[126]=0
$e[127] = (256 - ($sum % 256)) % 256;

die "EDID must be 128 bytes" unless @e == 128;
print pack('C*', @e);
