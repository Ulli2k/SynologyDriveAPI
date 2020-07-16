#/usr/bin/perl
use strict;
use warnings;

#Basis API (Python): https://pypi.org/project/synology-drive-api/#files

use Getopt::Std;
use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw( decode_json );
use Data::Dumper;

########################## User Config ##########################
my $ssl = 0;	# kein SSH auf der Diskstation da "LWP::Protocol::https" fehlt
							# Installierte Module prüfen "cpan -l"
my $ip 			= "127.0.0.1";
my $quiet	= 0;

##########################  Definitions ##########################
my $url;
my $ua;
my $sid = undef;

if($ssl) {
	$url = "https://$ip:5001/webapi/";
	my %ssl_options = (verify_hostname => 0, SSL_verify_mode => 0);
	my $ua = LWP::UserAgent->new(ssl_opts => \%ssl_options, protocols_allowed => ['https']);

} else {
	$url = "http://$ip:5000/webapi/";
	$ua = LWP::UserAgent->new()
}


#DS Drive - Querys/Coammands
my %querys	= ( 
								"info" =>	{
													"request" => "POST",
													"cgi" => "query.cgi",
													"api" => "SYNO.API.Info",
													"version" => "1",
													"method" => "query",
													"data" => { 'query' => 'SYNO.SynologyDrive.Files' }
													},

								"getTeamFoldersInfo" =>	{
													"request" => "GET",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.TeamFolders",
													"version" => "1",
													"method" => "list",
													"data" => { 'query' => 'SYNO.SynologyDrive.Files' }
													},

								"getFolderInfo" =>	{
													"request" => "GET",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "list",
													"data" => {	#path necessary
																			'filter' => {},
																			'sort_direction' => 'asc',
																			'sort_by' => 'owner',
																			'offset' => 0,
																			'limit' => 1000,
									                  }
													},
													
								"getFolderFileInfo" =>	{
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "update",
													"data" => {	} #path necessary
													},					
																					
								"login" =>	{
													"request" => "POST",								
													"cgi" => "auth.cgi",
													"api" => "SYNO.API.Auth",
													"version" => "2",
													"method" => "login",
													"data" => {	'session' => 'SynologyDrive',
																			'format' => 'cookie'
																		}
													},

								"logout" =>	{
													"request" => "POST",
													"cgi" => "auth.cgi",
													"api" => "SYNO.API.Auth",
													"version" => "2",
													"method" => "logout",
													"data" => { 'session' => 'SynologyDrive' }
													},

								"getLabels" =>	{
													"request" => "GET",
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Labels",
													"version" => "1",
													"method" => "list",
													"data" => { }
													},

								"createLabel" =>	{
													"request" => "PUT",
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Labels",
													"version" => "1",
													"method" => "create",
													"data" => { } #name: label name
        																#color: color name gray/red/orange/yellow/green/blue/purple
													},
													
								"deleteLabel" =>	{
													"request" => "DELETE",
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Labels",
													"version" => "1",
													"method" => "delete",
													"data" => { } #label_id
													},
								"setFileLabel" =>	{ #add Label to file
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "label",
													"data" => {	} # add Label 		-> { 'files' => '["id:564357428789948667"]', 'labels' => '[{"action":"add","label_id":"3"}]' }
																				# remove Label 	-> { 'files' => '["id:564357428789948667"]', 'labels' => '[{"action":"delete","label_id":"3"}]' } );
													},
													
								"listLabeledFiles" =>	{
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "list_labelled",
													"data" =>  { #label_id necessary 
																			'filter' => {},
																			'sort_direction' => 'desc',
																			'sort_by' => 'name',
																			'offset' => 0,
																			'limit' => 1000,
																		}
													},
													
								"createFolder" =>	{
													"request" => "PUT",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "create",
													"data" =>  { #path necessary 
																			'type' => 'folder',
																			'conflict_action' => 'autorename',
																		}
													},
													
								"uploadFile" =>	{
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "upload",
													"data" =>  { #path files necessary 
																			'type' => 'file',
																			'conflict_action' => 'version',
																		}
													},			
													
								"rename" =>	{
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "update",
													"data" =>  { } #path name necessary 
													},		
																																				
								"delete" =>	{
													"request" => "POST",								
													"cgi" => "entry.cgi",
													"api" => "SYNO.SynologyDrive.Files",
													"version" => "2",
													"method" => "delete",
													"data" =>  { #files ["id: "] necessary ! fid oder id?
																			'permanent' => 'false',
																			#'revisions' => 'version',
																		}
													},
							);
	
sub escape_hash {
    my %hash = @_;
    my @pairs;
    for my $key (keys %hash) {
        push @pairs, join "=", map { URI::Escape::uri_escape($_) } $key, $hash{$key};
    }
    return join "&", @pairs;
}

sub request($$) {
	my ($name, $data) = @_;
	
	my %post_data = ( 'api' 		=> $querys{$name}{'api'}, 
										'version' => $querys{$name}{'version'},
										'method' 	=> $querys{$name}{'method'},
									);
						
	%post_data = (%post_data, %{$querys{$name}{'data'}}) 	if($querys{$name}{'data'});
	%post_data = (%post_data, %{$data}) 									if($data);
	$post_data{'_sid'} = $sid 														if($sid);
	
	my $resp;
	if($querys{$name}{'request'} eq "POST") { #Content-Type: application/x-www-form-urlencoded; charset=UTF-8
		#$resp = $ua->request(POST $url . $querys{$name}{'cgi'}, [ %post_data ]);
		$resp = $ua->post( $url . $querys{$name}{'cgi'}, [ %post_data ] );
	} else { #GET, PUT, DELETE
		my $qStr = $url . $querys{$name}{'cgi'} . "?" . escape_hash(%post_data);
		#print $querys{$name}{'request'} . ": " . $qStr . "\n";
		my $request = HTTP::Request->new($querys{$name}{'request'}, $qStr);
		$resp = $ua->request($request);
	}
		
	my $message = undef;
	if ($resp->is_success) {
		  $message = $resp->decoded_content;
		  $message =~ s/\n+\z//;
		  my $json = decode_json($message);
		  if($json->{'success'}) {
		  	print "$name: $message\n" if(!$quiet);
		  	return $json->{'data'};
		  } else {
		  	print "$name Error : Drive (" . $json->{'error'}{'code'} . "): " , $message . "\n" if(!$quiet);
		  	return undef;
		  }
	} else {
		  print "$name Error: HTTP ". $querys{$name}{'request'} . " (" . $resp->code . "): " . $resp->message . "\n" if(!$quiet);
		  return undef;
	}
}

sub getFileID($) {
	my ($path) = @_;
	my $json = request("getFolderFileInfo", { 'path' => $path });
	return "id:" . $json->{'file_id'};
}

sub getLabels($) {
	my ($p) = @_;
	my %labels;
	my $json = request("getLabels", undef);

	foreach my $item ( @{$json->{'items'}} ) {
		$labels{lc($item->{'name'})} = $item->{'label_id'};
		print $item->{'label_id'} . ": " . $item->{'name'} . "\n" if(!$quiet || $p);

	}
	return %labels
}

########################## MAIN Function #############################
my $json;
my %options=();
getopts("hqs:u:p:l:Lf:w:i", \%options);

if(defined($options{h})) {
	print 	"Supported commands:\n"
			. " -u	user name of Syn Drive\n"
			. " -p	password of Syn Drive\n"
			. " -L	list available labels or of specfic file\n"
			. " -l	set labels (comma separated) for file\n"
			. " -w	list files with label\n"
			. " -f	file path\n"
			. " -q	quiet mode\n"
			. " -s	gültige ssid angeben\n"
			. " -i	info über verfügbare kommandos von DS Drive\n"
			. "\n";
			exit;
}

$quiet = 1 if (defined($options{q}));
$sid = $options{s} if (defined($options{s}));
	
	if (defined($options{u}) && defined($options{p}) ) {
		# Login
		$json = request("login", { 'account' => $options{u}, 'passwd' => $options{p} } );
		exit if(!$json);
		$sid = $json->{'sid'};
		$json = undef;
	}
	
	my $fileID;
	if(defined($options{f})) {
		$json = request("getFolderFileInfo", { 'path' => $options{f} } );
		print $json->{'name'} . ": " . $json->{'file_id'} . "\n";
	}
		
	if(defined($options{l}) && defined($options{f})) { #set Labels comma separated
		my $labelValue;
		my %labels = getLabels(0);
		foreach my $label ( split(',', $options{l}) ) {
			$labelValue .= '{"action":"add","label_id":' . $labels{lc($label)} . '},' if($labels{lc($label)});
		}
		$labelValue =~ s/,$//;
		request("setFileLabel", { 'files' => '["id:' . $json->{'file_id'} . '"]', 'labels' => '[' . $labelValue . ']' } ) if($labelValue);
	
	} elsif(defined($options{L})) { #list available labels or of specific file
		my $labels;
		if(!$json) { 
			getLabels(1);
		} else { 
			$labels = $json->{'labels'};
			foreach my $item ( @{$labels} ) {
				print $item->{'label_id'} . ": " . $item->{'name'} . "\n";
			}
		}

	} elsif(defined($options{w})) { #list files with specific label
		my %labels = getLabels(0);
		
		$json = request("listLabeledFiles", { 'label_id' => $labels{lc($options{w})} } )  if($labels{lc($options{w})});
		foreach my $item ( @{$json->{'items'}} ) {
			print $item->{'name'} . ": " . $item->{'file_id'} . "\n";
		}
		
	} elsif(defined($options{i})) { #list files with specific label
		request("info", undef);
	}

	# Logout
	request("logout",undef) if (defined($options{u}) && defined($options{p}) );

	

exit;



#request("FolderInfo", { '_sid' => $sid, 'path' => '/mydrive' } );
#request("setFileLabel", { 'files' => '["id:564357428789948667"]', 'labels' => '[{"action":"delete","label_id":"3"}]' } );



