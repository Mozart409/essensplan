-- Add up migration script here

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    role_id SERIAL PRIMARY KEY,
    role_name TEXT UNIQUE NOT NULL CHECK (role_name <> '')
);

-- Create tenants table
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id TEXT PRIMARY KEY CHECK (tenant_id ~* '^[0-9a-fA-F]{26}$'), -- ULID format
    tenant_public_id TEXT UNIQUE NOT NULL CHECK (tenant_public_id ~* '^[0-9a-fA-F]{20}$'), -- SQUID format
    tenant_name TEXT NOT NULL UNIQUE CHECK (tenant_name <> ''),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY CHECK (user_id ~* '^[0-9a-fA-F]{26}$'), -- ULID format
    user_public_id TEXT UNIQUE NOT NULL CHECK (user_public_id ~* '^[0-9a-fA-F]{20}$'), -- SQUID format
    username TEXT NOT NULL UNIQUE CHECK (username <> ''),
    email TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    password_hash TEXT NOT NULL CHECK (password_hash <> ''),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create user_tenants table
CREATE TABLE IF NOT EXISTS user_tenants (
    user_id TEXT NOT NULL CHECK (user_id ~* '^[0-9a-fA-F]{26}$'), -- ULID format
    tenant_id TEXT NOT NULL CHECK (tenant_id ~* '^[0-9a-fA-F]{26}$'), -- ULID format
    role_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, tenant_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(role_id)
);

-- Create index
CREATE INDEX CONCURRENTLY idx_user_tenants_tenant_id ON user_tenants (tenant_id);

-- Timestamp update function
CREATE FUNCTION update_timestamp() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updating timestamps
CREATE TRIGGER update_tenants_timestamp
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_users_timestamp
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_user_tenants_timestamp
    BEFORE UPDATE ON user_tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Optional: Trigger to ensure each tenant has an owner
CREATE FUNCTION ensure_tenant_has_owner() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM roles WHERE role_id = OLD.role_id AND role_name = 'owner') THEN
        IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND NOT EXISTS (SELECT 1 FROM roles WHERE role_id = NEW.role_id AND role_name = 'owner')) THEN
            IF NOT EXISTS (
                SELECT 1 FROM user_tenants ut
                JOIN roles r ON ut.role_id = r.role_id
                WHERE ut.tenant_id = OLD.tenant_id AND r.role_name = 'owner' AND ut.user_id != OLD.user_id
            ) THEN
                RAISE EXCEPTION 'Cannot remove the last owner of the tenant';
            END IF;
        END IF;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_tenant_has_owner_before_delete
    BEFORE DELETE ON user_tenants
    FOR EACH ROW
    EXECUTE FUNCTION ensure_tenant_has_owner();

CREATE TRIGGER ensure_tenant_has_owner_before_update
    BEFORE UPDATE ON user_tenants
    FOR EACH ROW
    EXECUTE FUNCTION ensure_tenant_has_owner();
