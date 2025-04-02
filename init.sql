-- Create predictions table if it doesn't exist
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
);

-- Reset the table if it exists but is in a bad state
DO $$
BEGIN
    -- Check if table exists but has wrong structure
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'predictions'
    ) THEN
        -- Check column structure
        IF NOT EXISTS (
            SELECT FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'predictions'
            AND column_name = 'predicted_digit'
        ) THEN
            -- Drop and recreate if structure is wrong
            DROP TABLE predictions;
            CREATE TABLE predictions (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                predicted_digit INTEGER NOT NULL,
                true_label INTEGER,
                confidence FLOAT NOT NULL
            );
        END IF;
    END IF;
END $$; 