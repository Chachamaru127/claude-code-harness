package writinglint

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

const (
	SchemaRelPath = "templates/schemas/writing-rule.v1.json"
	schemaURL     = "writing-rule.v1"
)

// DefaultSchemaPath returns the repo-relative schema path joined to repoRoot.
func DefaultSchemaPath(repoRoot string) string {
	return filepath.Join(repoRoot, SchemaRelPath)
}

// ValidateRule checks one rule against the writing-rule.v1 JSON Schema.
func ValidateRule(rule Rule, schemaPath string) error {
	schema, err := compileSchema(schemaPath)
	if err != nil {
		return err
	}

	payload, err := json.Marshal(rule)
	if err != nil {
		return fmt.Errorf("marshal rule: %w", err)
	}
	var instance any
	if err := json.Unmarshal(payload, &instance); err != nil {
		return fmt.Errorf("unmarshal rule json: %w", err)
	}
	if err := schema.Validate(instance); err != nil {
		return fmt.Errorf("schema validation: %w", err)
	}
	return nil
}

func validateRuleMap(instance map[string]interface{}, schemaPath string) error {
	schema, err := compileSchema(schemaPath)
	if err != nil {
		return err
	}
	if err := schema.Validate(instance); err != nil {
		return fmt.Errorf("schema validation: %w", err)
	}
	return nil
}

func compileSchema(schemaPath string) (*jsonschema.Schema, error) {
	schemaData, err := os.ReadFile(schemaPath)
	if err != nil {
		return nil, fmt.Errorf("read schema: %w", err)
	}
	schemaDoc, err := jsonschema.UnmarshalJSON(bytes.NewReader(schemaData))
	if err != nil {
		return nil, fmt.Errorf("parse schema json: %w", err)
	}
	compiler := jsonschema.NewCompiler()
	if err := compiler.AddResource(schemaURL, schemaDoc); err != nil {
		return nil, fmt.Errorf("add schema resource: %w", err)
	}
	schema, err := compiler.Compile(schemaURL)
	if err != nil {
		return nil, fmt.Errorf("compile schema: %w", err)
	}
	return schema, nil
}
