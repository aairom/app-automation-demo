from flask import Flask, render_template, request, jsonify, redirect, url_for
import sqlite3
import os
from datetime import datetime
import hashlib
import hvac
import re
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlite3 import SQLite3Instrumentor

# Initialize OpenTelemetry
resource = Resource.create({"service.name": "member-management-app"})

# Trace provider
trace_provider = TracerProvider(resource=resource)
otlp_trace_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
    insecure=True
)
trace_provider.add_span_processor(BatchSpanProcessor(otlp_trace_exporter))
trace.set_tracer_provider(trace_provider)

# Metrics provider
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(
        endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
        insecure=True
    )
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Initialize Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key')

# Instrument Flask and SQLite
FlaskInstrumentor().instrument_app(app)
SQLite3Instrumentor().instrument()

# Get tracer and meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Create metrics
member_counter = meter.create_counter(
    "member.operations",
    description="Number of member operations",
    unit="1"
)

# Database configuration
DATABASE = os.getenv('DATABASE_PATH', 'members.db')

# Vault configuration
VAULT_ADDR = os.getenv('VAULT_ADDR', 'http://localhost:8200')
VAULT_TOKEN = os.getenv('VAULT_TOKEN', 'dev-token')
VAULT_MOUNT_POINT = os.getenv('VAULT_MOUNT_POINT', 'secret')

def get_vault_client():
    """Initialize and return Vault client"""
    try:
        client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)
        if not client.is_authenticated():
            print("Warning: Vault authentication failed")
            return None
        return client
    except Exception as e:
        print(f"Warning: Could not connect to Vault: {e}")
        return None

def store_secret_in_vault(username, secret_type, secret_value):
    """Store a secret in Vault"""
    with tracer.start_as_current_span("store_secret_in_vault"):
        client = get_vault_client()
        if client:
            try:
                path = f"{VAULT_MOUNT_POINT}/data/members/{username}/{secret_type}"
                client.secrets.kv.v2.create_or_update_secret(
                    path=f"members/{username}/{secret_type}",
                    secret=dict(value=secret_value),
                    mount_point=VAULT_MOUNT_POINT
                )
                return True
            except Exception as e:
                print(f"Error storing secret in Vault: {e}")
                return False
        return False

def get_secret_from_vault(username, secret_type):
    """Retrieve a secret from Vault"""
    with tracer.start_as_current_span("get_secret_from_vault"):
        client = get_vault_client()
        if client:
            try:
                path = f"members/{username}/{secret_type}"
                secret = client.secrets.kv.v2.read_secret_version(
                    path=path,
                    mount_point=VAULT_MOUNT_POINT
                )
                return secret['data']['data']['value']
            except Exception as e:
                print(f"Error retrieving secret from Vault: {e}")
                return None
        return None

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def get_db_connection():
    """Create database connection"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database with schema and sample data"""
    with tracer.start_as_current_span("init_db"):
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                last_name TEXT NOT NULL,
                first_name TEXT NOT NULL,
                date_of_birth TEXT NOT NULL,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Check if we need to add sample data
        cursor.execute('SELECT COUNT(*) FROM members')
        count = cursor.fetchone()[0]
        
        if count == 0:
            # Insert 5 sample records
            sample_members = [
                ('Smith', 'John', '1985-03-15', 'jsmith', 'password123', 'secret_data_1'),
                ('Johnson', 'Emily', '1990-07-22', 'ejohnson', 'password456', 'secret_data_2'),
                ('Williams', 'Michael', '1988-11-30', 'mwilliams', 'password789', 'secret_data_3'),
                ('Brown', 'Sarah', '1992-05-18', 'sbrown', 'passwordabc', 'secret_data_4'),
                ('Davis', 'Robert', '1987-09-25', 'rdavis', 'passwordxyz', 'secret_data_5')
            ]
            
            for last_name, first_name, dob, username, password, secret in sample_members:
                password_hash = hash_password(password)
                cursor.execute('''
                    INSERT INTO members (last_name, first_name, date_of_birth, username, password_hash)
                    VALUES (?, ?, ?, ?, ?)
                ''', (last_name, first_name, dob, username, password_hash))
                
                # Store secret in Vault
                store_secret_in_vault(username, 'secret', secret)
        
        conn.commit()
        conn.close()

@app.route('/')
def index():
    """Home page - list all members with optional search"""
    with tracer.start_as_current_span("index"):
        search_query = request.args.get('search', '').strip()
        conn = get_db_connection()
        
        if search_query:
            # Convert wildcard pattern to SQL LIKE pattern
            # Replace * with % for SQL LIKE
            sql_pattern = search_query.replace('*', '%')
            
            # Search in last_name, first_name, and username
            members = conn.execute('''
                SELECT * FROM members
                WHERE last_name LIKE ?
                   OR first_name LIKE ?
                   OR username LIKE ?
                ORDER BY last_name, first_name
            ''', (sql_pattern, sql_pattern, sql_pattern)).fetchall()
            
            member_counter.add(1, {"operation": "search"})
        else:
            members = conn.execute('SELECT * FROM members ORDER BY last_name, first_name').fetchall()
            member_counter.add(1, {"operation": "list"})
        
        conn.close()
        return render_template('index.html', members=members, search_query=search_query)

@app.route('/member/<int:member_id>')
def view_member(member_id):
    """View member details"""
    with tracer.start_as_current_span("view_member"):
        conn = get_db_connection()
        member = conn.execute('SELECT * FROM members WHERE id = ?', (member_id,)).fetchone()
        conn.close()
        
        if member is None:
            return "Member not found", 404
        
        # Retrieve secret from Vault
        secret = get_secret_from_vault(member['username'], 'secret')
        
        member_counter.add(1, {"operation": "view"})
        return render_template('view_member.html', member=member, secret=secret)

@app.route('/member/new', methods=['GET', 'POST'])
def create_member():
    """Create new member"""
    with tracer.start_as_current_span("create_member"):
        if request.method == 'POST':
            last_name = request.form['last_name']
            first_name = request.form['first_name']
            date_of_birth = request.form['date_of_birth']
            username = request.form['username']
            password = request.form['password']
            secret = request.form.get('secret', '')
            
            password_hash = hash_password(password)
            
            conn = get_db_connection()
            try:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO members (last_name, first_name, date_of_birth, username, password_hash)
                    VALUES (?, ?, ?, ?, ?)
                ''', (last_name, first_name, date_of_birth, username, password_hash))
                conn.commit()
                
                # Store secret in Vault
                if secret:
                    store_secret_in_vault(username, 'secret', secret)
                
                member_counter.add(1, {"operation": "create"})
                return redirect(url_for('index'))
            except sqlite3.IntegrityError:
                return "Username already exists", 400
            finally:
                conn.close()
        
        return render_template('create_member.html')

@app.route('/member/<int:member_id>/edit', methods=['GET', 'POST'])
def edit_member(member_id):
    """Edit member"""
    with tracer.start_as_current_span("edit_member"):
        conn = get_db_connection()
        member = conn.execute('SELECT * FROM members WHERE id = ?', (member_id,)).fetchone()
        
        if member is None:
            conn.close()
            return "Member not found", 404
        
        if request.method == 'POST':
            last_name = request.form['last_name']
            first_name = request.form['first_name']
            date_of_birth = request.form['date_of_birth']
            password = request.form.get('password')
            secret = request.form.get('secret')
            
            if password:
                password_hash = hash_password(password)
                conn.execute('''
                    UPDATE members 
                    SET last_name = ?, first_name = ?, date_of_birth = ?, password_hash = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (last_name, first_name, date_of_birth, password_hash, member_id))
            else:
                conn.execute('''
                    UPDATE members 
                    SET last_name = ?, first_name = ?, date_of_birth = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (last_name, first_name, date_of_birth, member_id))
            
            conn.commit()
            
            # Update secret in Vault if provided
            if secret:
                store_secret_in_vault(member['username'], 'secret', secret)
            
            conn.close()
            member_counter.add(1, {"operation": "update"})
            return redirect(url_for('view_member', member_id=member_id))
        
        # Retrieve secret from Vault
        secret = get_secret_from_vault(member['username'], 'secret')
        conn.close()
        
        return render_template('edit_member.html', member=member, secret=secret)

@app.route('/member/<int:member_id>/delete', methods=['POST'])
def delete_member(member_id):
    """Delete member"""
    with tracer.start_as_current_span("delete_member"):
        conn = get_db_connection()
        member = conn.execute('SELECT username FROM members WHERE id = ?', (member_id,)).fetchone()
        
        if member:
            conn.execute('DELETE FROM members WHERE id = ?', (member_id,))
            conn.commit()
            member_counter.add(1, {"operation": "delete"})
        
        conn.close()
        return redirect(url_for('index'))

@app.route('/admin')
def admin():
    """Admin dashboard with links to monitoring tools"""
    with tracer.start_as_current_span("admin"):
        return render_template('admin.html')

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()})

@app.route('/metrics')
def metrics_endpoint():
    """Metrics endpoint for Prometheus"""
    return "Metrics are exported via OTLP", 200

if __name__ == '__main__':
    init_db()
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)

# Made with Bob
