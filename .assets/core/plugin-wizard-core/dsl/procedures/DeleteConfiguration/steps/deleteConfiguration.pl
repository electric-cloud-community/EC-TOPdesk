#
#  Copyright 2016 Electric Cloud, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
use ElectricCommander;

# get an EC object
my $ec = ElectricCommander->new();
$ec->abortOnError(0);

my $config = '$[config]';

my $PLUGIN_NAME = '@PLUGIN_KEY@';
my $project_name = '/plugins/@PLUGIN_NAME@/project';

if (! defined $PLUGIN_NAME || $PLUGIN_NAME eq "\@PLUGIN_KEY\@") {
    exit_with_error("PLUGIN_NAME must be defined\n");
}

if (! defined $config || $config eq '') {
    exit_with_error("You have to supply non-empty configuration name\n");
}

# check to see if a config with this name already exists before we do anything else
my $xpath = $ec->getProperty("$project_name/ec_plugin_cfgs/$config");
my $property = $xpath->findvalue('//response/property/propertyName');

if (! defined $property || $property eq '') {
    exit_with_error("Error: A configuration named '$config' does not exist.");
}

# Delete configuration property sheet
$ec->deleteProperty("$project_name/ec_plugin_cfgs/$config");


# Delete credentials
my $credentials = $ec->getCredentials({projectName => '@PLUGIN_NAME@'});
for my $cred ($credentials->findnodes('//credential')) {
    my $name = $cred->findvalue('credentialName')->string_value;
    if ($name =~ /^$config/) {
        $ec->deleteCredential({projectName => '@PLUGIN_NAME@', credentialName => $name});
    }
}

sub exit_with_error {
    my ( $error_message ) = @_;
    $ec->setProperty('/myJob/configError', $error_message);
    print $error_message;
    exit 1;
}


