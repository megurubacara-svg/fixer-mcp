package main

import (
	"testing"
	"time"
)

func TestIsRetryableRateLimit(t *testing.T) {
	tests := []struct {
		logText string
		want    bool
	}{
		{"something 429 something", true},
		{"rate limit exceeded", true},
		{"Too Many Requests", true},
		{"just a normal error 500", false},
	}
	for _, tc := range tests {
		if got := isRetryableRateLimit(tc.logText); got != tc.want {
			t.Errorf("isRetryableRateLimit(%q) = %v, want %v", tc.logText, got, tc.want)
		}
	}
}

func TestCalculateBackoff(t *testing.T) {
	tests := []struct {
		attempts int
	}{
		{0}, {1}, {2}, {3}, {4}, {5},
	}
	for _, tc := range tests {
		got := calculateBackoff(tc.attempts)
		expected := time.Duration(1<<tc.attempts) * time.Minute
		if 1<<tc.attempts > 15 {
			expected = 15 * time.Minute
		}
		expected += time.Duration(tc.attempts) * time.Second

		if got != expected {
			t.Errorf("calculateBackoff(%d) = %v, want %v", tc.attempts, got, expected)
		}
	}
}
