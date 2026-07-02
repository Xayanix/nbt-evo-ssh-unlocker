# NBT EVO Reversing Work
Some notes on FSC certstore patching

## Background & process
Unlike FDL coding FSC coding involves giving the NBT unit a certificate signed by BMW that it checks against a public key stored on the device.

Getting the device to accept a self-signed FSC code can be accomplished a few ways:
  * Computing BMW's signing key and being able to sign valid FSCs (unlikely, until quantum computers)
  * Disabling signature validation (lots of RE work, app decompilation etc)
  * Replacing the on-device public key with our own (<== our method, less RE work)

So the trick becomes, how do we get write access to the NBT in order to overwrite the pubkey with our own?

The flashing (software update) process for the NBT works like this:
1. Diag session opened, flashing mode session opened, device reboots to bootloader
2. E-sys flashes software to a secondary partition
3. Secondary partition software is checksummed + validated, then promoted to primary boot partition

But the write location is determined by the client, and since the checksumming + validation only happens when a partition is promoted, we can just write to the primary partition and not worry about signatures.

We can craft an SWFL that targets *just* the certificate modulus (128 bytes) on the primary partition. There's a brick risk if we overwrite the wrong space since we're targeting live, but worst case we can restore the unit from boot mode.

Once applied we just need to understand the format of the FSC file and replace the signatures with our own - then e-sys will apply them via the factory routines and they will be accepted by the NBT.

## Prep: CA creation
Step one here will be to create our own CA that we'll sign the FSC files with. It should be RSA-1024 with e=3 to match the format of what's there:
```
# generate CA
openssl genrsa -3 -out nbt-ca.pem 1024

# get the modulus and print it little-endian
openssl rsa -in nbt-ca.pem -noout -modulus | sed 's/^Modulus=//' | fold -w2 | tac | tr -d '\n' | xxd -r -p > nbt-ca.modulus.bin

# sanity check that this is 128b
wc -c < nbt-ca.modulus.bin
```

## Flash NBT to enable debug mode (ssh)
Above we described a process in which we could overwrite arbitrary parts of the filesystem. For speed and reliability we will flash a much smaller change (enable ssh) and apply our cert overwrite over SSH
`./nbt_optdebug_flash.py` includes the OPT_DEBUG enable override inline and will handle the obd/enet parts of flashing for you

## Apply our CA to the NBT
With SSH enabled we can copy our CA modulus over and overwrite the one in NBT
`ssh root@169.254.199.119 'cat > /var/userca.bin' < "$TARGETBIN"`

now overwrite the stock ca
`ssh root@169.254.199.119 "mount -u -o rw /fs/sda0 && dd if=/var/userca.bin of=/fs/sda0/opt/car/bin/NBTCarHU bs=1 seek=0x35A300 count=128 conv=notrunc && sync && mount -u -o ro /fs/sda0"`


## Generate FSC codes from our CA
...continued later
