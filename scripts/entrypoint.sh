#!/bin/bash

echo "EntryPoint"

#RUN chown -R www-data:www-data /var/www/html && \

#TODO: need 2 ways here?
if [ -e version.txt ]; then
	apache2-foreground
else
	#composer.phar update --prefer-stable --prefer-source && \
	#	echo "0.1" > version.txt && \
	apache2-foreground
fi
