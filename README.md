# Nextcloud for OpenShift 3

This repository contains an OpenShift 3 template to easily deploy Nextcloud on OpenShift.

## Installation

### 0 Create OpenShift project

Create an OpenShift project if not already provided by the service

```
PROJECT=nextcloud
oc new-project $PROJECT
```

### 1 Deploy Database

```
oc -n openshift process mariadb-persistent -p MYSQL_DATABASE=nextcloud | oc -n $PROJECT create -f -
```

### 2 Deploy Nextcloud

```
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/nextcloud.yaml -p NEXTCLOUD_HOST=nextcloud.example.com | oc -n $PROJECT create -f -
```

#### Template parameters

Execute the following command to get the available parameters:

```
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/nextcloud.yaml --parameters
```

### 3 Configure Nextcloud

* Navigate to http://nextcloud.example.com
* Fill in the form and finish the installation. The DB credentials can be 
  found in the secret `mariadb`. In the Webconsole it can be found under
  `Resources -> Secrets -> mariadb -> Reveal Secret`

**Hints**

* You might want to enable TLS for your instance

## Backup

### Database

You can use the provided DB dump `CronJob` template:

```
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/mariadb-backup.yaml | oc -n MYNAMESPACE create -f -
```

This script dumps the DB to the same PV as the database stores it's data.
You must make sure that you copy these files away to a real backup location.

### Files

To backup files, a simple solution would be to run f.e. [restic](http://restic.readthedocs.io/) in a Pod
as a `CronJob` and mount the PVCs as volumes. Then use an S3 endpoint for restic
to backup data to.

## Notes

* Nextcloud Cronjob is called from a `CronJob` object every 15 minutes
* The Dockerfile just add the `nginx.conf` to the Alpine Nginx container

To use the `occ` CLI, you can use `oc exec`:

```
oc get pods
oc exec NEXTCLOUDPOD -c nextcloud -ti php occ
```

## Ideas / open issues

* Use sclorg Nginx instead of Alpine Nginx for better OpenShift compatibility
* Autoconfigure Nextcloud using `autoconfig.php`
* Provide restic Backup example

## Dependency on Nextcloud Community Edition

This OpenShift template uses software provided by the Nextcloud GmbH, specially the official Nextcloud docker image (see references below).

These components are licenced under AGPL-3.0 with their copyright belonging to the Nextcloud team. Also the Nextcloud trademark and logo belong to Nextcloud GmbH.

References:

* <https://nextcloud.com/install/#instructions-server>
* <https://github.com/nextcloud/docker>
* <https://hub.docker.com/_/nextcloud/>
* <http://www.gnu.org/licenses/agpl-3.0.html>

## License for the OpenShift template

For compatibility with the Nextcloud software components, that this template depends on, this work is published under the same license, AGPL-3.0.

Copyright (C) 2019-2020, Jan Grieb

> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU Affero General Public License as published by
> the Free Software Foundation, either version 3 of the License, or
> (at your option) any later version.
>
> This program is distributed in the hope that it will be useful,
> but WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
> GNU Affero General Public License for more details.
>
> You should have received a copy of the GNU Affero General Public License
> along with this program.  The license is location in the file `LICENSE`
> in this repository. Also, see the public document on
> <http://www.gnu.org/licenses/>.

This template is based on work originally published to <https://github.com/tobru/nextcloud-openshift> with the following license:

> MIT License
>
> Copyright (c) 2017 Tobias Brunner
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## Contributions

Very welcome!

1. Fork it (https://github.com/jngrb/nextcloud-openshift/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
