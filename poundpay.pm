package Poundpay;

use LWP::UserAgent;
use Modern::Perl;
use Moose;
use JSON qw(from_json to_json);
use URI::Escape;
use Data::Dumper;

has developer_sid => (is => 'rw', required => 1);
has auth_token => (is => 'rw', required => 1);
has api_url => (is => 'rw', default => 'https://api-sandbox.poundpay.com/');
has api_version => (is => 'rw', default => 'silver');
has base_url => (is => 'ro', lazy => 1, 
    default => sub { 
        my $self = shift;
        return $self->api_url . $self->api_version;
    });
has ua => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->default_header(content_type =>
            'application/json');
        $ua->timeout(5);
        return $ua;
    },
);

# --------------------- Developers -------------------------- #
sub get_accounts {
    my ($self) = @_;
    return _make_request($self, GET => '/developers');
}

sub get_account {
    my ($self, $developer_sid) = @_;
    return _make_request($self, GET => "/developers/$developer_sid");
}

sub update_account {
    my ($self, $developer_sid, $developer_data) = @_;
    my $params = substr(_build_params($self, $developer_data), 1, -1);
    return _make_request($self, 
        PUT => "/developers/$developer_sid",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

sub get_account_history {
    my ($self, $developer_sid) = @_;
    return _make_request($self, GET => "/developers/$developer_sid/history");
}

# ------------------- Payments -------------------------#
sub get_payments {
    my ($self, $developer_sid) = @_;
    return _make_request($self, GET => "/payments");
}

sub create_payment {
    my ($self, $amount, $payer_fee_amount, $recipient_fee_amount, 
        $payer_email_address, $recipient_email_address, $description) = @_;

    # Build payment data
    my $payment_data = {
        amount                  => $amount,
        payer_fee_amount        => $payer_fee_amount,
        recipient_fee_amount    => $recipient_fee_amount,
        payer_email_address     => $payer_email_address,
        recipient_email_address => $recipient_email_address
    };
    $payment_data->{description} = $description;
    my $params = substr(_build_params($self, $payment_data), 1, -1);

    return _make_request($self, 
        POST => "/payments",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

sub authorize_payments {
    my ($self, $payment_ids) = @_;

    # Build payment data
    my $params = '';
    for (@$payment_ids){
        $params .= "sid=$_&";
    }
    $params .= "state=AUTHORIZED";

    return _make_request($self, 
        PUT => "/payments",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

sub escrow_payments {
    my ($self, $payment_ids) = @_;

    # Build payment data
    my $params = '';
    for (@$payment_ids){
        $params .= "sid=$_&";
    }
    $params .= "state=ESCROWED";

    return _make_request($self, 
        PUT => "/payments",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

sub get_payment {
    my ($self, $payment_sid) = @_;
    return _make_request($self, GET => "/payments/$payment_sid");
}

sub update_payment {
    my ($self, $payment_sid, $payment_data) = @_;
    my $params = substr(_build_params($self, $payment_data), 1, -1);

    return _make_request($self, 
        PUT => "/payments/$payment_sid",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

sub authorize_payment {
    my ($self, $payment_sid) = @_;
    return $self->update_payment($payment_sid, { state => 'AUTHORIZED' });
}

sub escrow_payment {
    my ($self, $payment_sid) = @_;
    return $self->update_payment($payment_sid, { state => 'ESCROWED' });
}

sub release_payment {
    my ($self, $payment_sid) = @_;
    return $self->update_payment($payment_sid, { state => 'RELEASED' });
}

sub cancel_payment {
    my ($self, $payment_sid) = @_;
    return $self->update_payment($payment_sid, { state => 'CANCELED' });
}


# ------------------- Users -----------------------#
sub create_user {
    my ($self, $firstname, $lastname, $email) = @_;

    # Build user data
    my $user_data = {
        first_name       => $firstname,
        last_name        => $lastname,
        email_address    => $email
    };
    my $params = substr(_build_params($self, $user_data), 1, -1);

    return _make_request($self, 
        POST => "/users",
        [ "Content-Type" => "application/x-www-form-urlencoded",
        ],
        $params
    );
}

# ------------------- Helper Functions -----------------#
sub _build_params {
    my ($self, $filter) = @_;

    my $params = "?";
    for (keys %$filter){
        $params .= "$_=$filter->{$_}&" if defined($filter->{$_});
    }
    return $params;
}

sub _make_request {
    my ($self, $method, $path, $headers, $content) = @_;
    my $ua = $self->ua;
    my $base_url = $self->base_url;
    my $req_url = $base_url . $path;

    my $req = HTTP::Request->new($method => $req_url, $headers, $content);
    $req->authorization_basic($self->developer_sid, $self->auth_token);
    my $res = $ua->request($req);

    my $result; 
    if($res->is_success) {
        $result = from_json($res->content);
        $result->{success} = $res->is_success;
    } else {
        $result->{error} = $res->message;
    }
    return $result;
}

1;

