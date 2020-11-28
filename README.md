# Nextcloud for OpenShift 3

This repository contains an OpenShift 3 template to easily deploy Nextcloud on OpenShift.

## Installation

### 0 Create OpenShift project

Create an OpenShift project if not already provided by the service

```[bash]
PROJECT=nextcloud
oc new-project $PROJECT
```

### 1a Deploy Database

```[bash]
oc -n openshift process mariadb-persistent -p MYSQL_DATABASE=nextcloud | oc -n $PROJECT create -f -
```

### 1b Deploy Redis database

```[bash]
oc -n openshift process redis-ephemeral | oc -n $PROJECT create -f -
```

If the Nextcloud pod is to be deployed only on selected nodes, apply the node selector also to the Redis deployment (here, we use the node selector 'appclass=main'). To do so, you can edit the deployment configuration YAML as follows.

```[yaml]
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  [...]
spec:
  [...]
  template:
    metadata:
      [...]
    spec:
      nodeSelector:
        appclass: main
      [...]
```

### 2 Deploy Nextcloud

```[bash]
NEXTCLOUD_HOST=nextcloud.example.com
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/nextcloud.yaml -p NEXTCLOUD_HOST=$NEXTCLOUD_HOST | oc -n $PROJECT create -f -
```

#### Template parameters

Execute the following command to get the available parameters:

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/nextcloud.yaml --parameters
```

#### Redis Cache for Sessions without root privileges

In order to use the redis cache for sessions if the container is run without root privileges, you will need to use a modified Nextcloud image.

Build your modified image with the following build template:

```[bash]
oc process -f nc_image_fix/nextcloud-image-fix.yaml | oc apply -f -
```

After the build has finished, change you nextcloud deyploment config to use the fixed image:

```[bash]
oc patch dc nextcloud --patch='{"spec":{"template":{"spec":{"containers":[{"name": "nextcloud", "image":"nextcloud-fixed:latest"}]}},"triggers":[{"type": "ImageChange","imageChangeParams": {"automatic": true,"containerNames": ["nextcloud"],"from":{"kind": "ImageStreamTag", "name": "nextcloud-fixed:latest", "namespace": "nextcloud"}}},{"type": "ConfigChange"}]}}'
```

### 3 Configure Nextcloud

* Navigate to `$NEXTCLOUD_HOST`, here <http://nextcloud.example.com>
* Fill in the form and finish the installation. The DB credentials can be found in the secret `mariadb`. In the Webconsole it can be found under `Resources -> Secrets -> mariadb -> Reveal Secret`

#### Hints

* Change the config to include 'localhost' as a trusted proxy: `'trusted_proxies' => ['127.0.0.1', '::1'],`.
* You might want to enable TLS for your instance.
* Make sure that the caching configuration is as follows (see <https://docs.nextcloud.com/server/17/admin_manual/configuration_server/caching_configuration.html> for reference):

```[php]
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.distributed' => '\\OC\Memcache\\Redis',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'redis' => [
     'host' => 'redis.<project>.svc',
     'port' => 6379,
     'password' => '<redis-secret>',
],
```

## Backup

### Database

You can use the provided DB dump `CronJob` template:

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/nextcloud-openshift/master/mariadb-backup.yaml | oc -n PROJECT create -f -
```

This script dumps the DB to the same PV as the database stores it's data.
You must make sure that you copy these files away to a real backup location.

### Files

To backup files, a simple solution would be to run f.e. [restic](http://restic.readthedocs.io/) in a Pod as a `CronJob` and mount the PVCs as volumes. Then use an S3 endpoint for restic to backup data to.

## Notes

* Nextcloud Cronjob is called from a `CronJob` object every 15 minutes
* The Dockerfile just add the `nginx.conf` to the Alpine Nginx container

To use the `occ` CLI, you can use `oc exec`:

```[bash]
oc get pods
oc exec NEXTCLOUDPOD -c nextcloud -ti php occ
```

## Automatic update and upgrade deployments

### Jenkins pipeline

We use an (ephemeral) Jenkins for automatic deployments of configuration updates and image upgrades. First, deploy the Jekins POD:

```[bash]
oc -n openshift process jenkins-ephemeral | oc -n $PROJECT create -f -
```

As as the main PODs, you might want to deploy the Jenkins container only on selected nodes. (E.g., you can the same node selector, 'appclass=main'.)

Note, Jenkins might take a long time to deploy.

After having logged into Jenkins for the first time, you can roll out the JenkinsPipeline build configuration:

```[bash]
oc project $PROJECT
oc process -f update-pipeline.yaml -p NEXTCLOUD_HOST=nextcloud.example.com | oc apply -f -
```

This pipeline updates the deployment configuration to the newest version from the template as checked in on the master branch on Github.

### Maintenance jobs

To set Nextcloud into maintenance mode, you can run the maintenance Job:

```[bash]
#oc project $PROJECT # assumed to still be set
oc process -f nextcloud-maintenance.yaml -p ON_OFF=on | oc create -f -
```

To disable the maintenance mode, run the 'opposite' Job with `ON_OFF=off`.

```[bash]
#oc project $PROJECT # assumed to still be set
oc process -f nextcloud-maintenance.yaml -p ON_OFF=off | oc create -f -
```

### Automatic upgrades

In order to upgrade the Nextcloud image and run the upgrade script automatically for the persistent data volume and the database, run the 'image-upgrade' pipeline.

Note that just upgrading the image for the regular deployment cannot be recommended, especially when the replica count is greater than one. In such cases, the migration script of the Nextcloud image might run in several containers in parallel.

```[bash]
#oc project $PROJECT # assumed to still be set
oc process -f upgrade/upgrade-pipeline.yaml -p NEXTCLOUD_HOST=$NEXTCLOUD_HOST -p OLD_NEXTCLOUD_IMAGE_TAG=17.0.5-fpm -p NEW_NEXTCLOUD_IMAGE_TAG=18.0.4-fpm | oc apply -f -
oc start-build image-upgrade-pipeline
```

This pipeline will first set the maintenance mode, then upgrade everything, and finally unset the maintenance mode.

## Ideas / open issues

* Use sclorg Nginx instead of Alpine Nginx for better OpenShift compatibility
* Autoconfigure Nextcloud using `autoconfig.php`
* Finalize maintenance and upgrade jobs
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

1. Fork it (<https://github.com/jngrb/nextcloud-openshift/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
