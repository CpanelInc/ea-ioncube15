# ea-ioncube15

This repository builds the ea-ioncube15 package for cPanel & WHM, which provides ionCube Loader support for PHP.

## Overview

ionCube provides PHP loaders that enable execution of encoded PHP files. This package installs the appropriate ionCube loaders for all supported PHP versions in the EasyApache 4 system.

## Special Build Process: PHP 8.5 Support

### Why `get_for_all_php.pl` Exists

As of early 2026, ionCube's **stable release (15.0.x)** includes loaders for PHP 5.6 through 8.4, but does **not yet include PHP 8.5** support.

However, ionCube's **beta release (15.5.x)** includes **only** PHP 8.5 loaders - it does not contain loaders for earlier PHP versions.

This is why we cannot simply use the beta release alone. To support all PHP versions (including 8.5), we needed a way to:
1. Use the stable release for all standard PHP versions (5.6-8.4)
2. Add PHP 8.5 loaders from the beta release
3. Combine them into a single tarball for packaging

### What `get_for_all_php.pl` Does

This script creates a **hybrid tarball** by:

1. **Downloading** the stable release (15.0.x) - contains loaders for PHP 5.6-8.4
2. **Downloading** the beta release (15.5.x) - contains **only** PHP 8.5 loaders
3. **Extracting** both tarballs to temporary directories
4. **Copying** all files from the stable release to a merge directory
5. **Copying** only the `.so` loader files from the beta release (adds PHP 8.5 loaders)
6. **Creating** a combined tarball with all loaders
7. **Placing** the combined tarball in `SOURCES/ioncube_loaders_lin_x86-64.tar.gz`

The result is a tarball that contains:
- Stable loaders for PHP 5.6-8.4 (from stable release)
- Beta loader for PHP 8.5 only (from beta release)

### Implementation Details

To accomplish this, `find-latest-version` was made more complex so that `get_for_all_php.pl` can load it as a **modulino**. This allows the script to:
- Reuse the version-finding logic from `find-latest-version` 
- Find both the stable and beta versions of the loaders
- Perform the merging of the tarballs programmatically

This modulino approach avoids code duplication and keeps the version-finding logic centralized in one place.

### When to Run This Script

**You MUST run this script each time you update the package** until ionCube's stable release includes PHP 8.5 support.

Once PHP 8.5 support is available in the stable release, we can:
1. Remove `get_for_all_php.pl`
2. Return to using the standard `find-latest-version` script
3. Update the spec file to fetch directly from stable releases

### Usage

Run from the repository root:

```bash
./get_for_all_php.pl
```

Options:
- `--nocleanup` - Keep the temporary assembly directory after completion (useful for debugging)

### Requirements

- Perl with the following modules:
  - HTTP::Tiny
  - File::Temp
  - File::Path
  - File::Copy
  - File::Find
  - Cwd
  - Getopt::Long
- Internet connectivity to download from ionCube's servers
- The `find-latest-version` script in the same directory

### What Happens Next

After running `get_for_all_php.pl`:

1. The combined tarball is placed in `SOURCES/ioncube_loaders_lin_x86-64.tar.gz`
2. Build the RPM normally using `make` or your standard build process
3. The spec file will use this tarball as its source

## Standard Build Process

Once `get_for_all_php.pl` has been run:

```bash
et obs --watch
```

This will build the RPM packages using the combined tarball.

## Future Cleanup

Monitor ionCube releases at https://www.ioncube.com/loaders.php

When the stable release includes PHP 8.5:
1. Delete `get_for_all_php.pl`
2. Update build documentation
3. Verify the spec file works with standard stable releases

## License

Copyright 2026 WebPros International, LLC. All rights reserved.
