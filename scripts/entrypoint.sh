#!/bin/bash

echo "EntryPoint"

#RUN chown -R www-data:www-data /var/www/html && \

#TODO: need 2 ways here?
if [ -e composer.lock ]; then
	apache2-foreground
else
	composer.phar update --prefer-stable --prefer-source && \
	    touch FIRST_INSTALL && \
	    apache2-foreground
fi
