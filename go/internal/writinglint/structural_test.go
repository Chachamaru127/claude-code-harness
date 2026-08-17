package writinglint

import "testing"

func TestDetectRepeatedSentenceEndings_PositiveThreeInARow(t *testing.T) {
	text := "これはペンだ。それもペンだ。あれもペンだ。"
	runs := DetectRepeatedSentenceEndings(text)
	if len(runs) != 1 {
		t.Fatalf("len(runs) = %d, want 1: %+v", len(runs), runs)
	}
	if runs[0].Ending != "だ" || runs[0].Count != 3 || runs[0].Start != 0 {
		t.Fatalf("runs[0] = %+v, want {Ending:だ Count:3 Start:0}", runs[0])
	}
}

func TestDetectRepeatedSentenceEndings_NegativeVariedEndings(t *testing.T) {
	text := "これはペンだ。それはノートです。あれもペンだ。"
	runs := DetectRepeatedSentenceEndings(text)
	if len(runs) != 0 {
		t.Fatalf("len(runs) = %d, want 0: %+v", len(runs), runs)
	}
}

func TestDetectRepeatedSentenceEndings_NegativeOnlyTwoInARow(t *testing.T) {
	text := "これはペンだ。それもペンだ。あれはノートです。"
	runs := DetectRepeatedSentenceEndings(text)
	if len(runs) != 0 {
		t.Fatalf("len(runs) = %d, want 0 (only 2 consecutive, below threshold): %+v", len(runs), runs)
	}
}

func TestDetectStyleMixing_PositivePoliteAndPlainInSameText(t *testing.T) {
	text := "これはペンです。それはノートだ。"
	m := DetectStyleMixing(text)
	if !m.Mixed() {
		t.Fatalf("m = %+v, want Mixed() = true", m)
	}
	if m.PoliteCount != 1 || m.PlainCount != 1 {
		t.Fatalf("m = %+v, want PoliteCount=1 PlainCount=1", m)
	}
}

func TestDetectStyleMixing_NegativeConsistentPolite(t *testing.T) {
	text := "これはペンです。それもノートです。"
	m := DetectStyleMixing(text)
	if m.Mixed() {
		t.Fatalf("m = %+v, want Mixed() = false (consistent 敬体)", m)
	}
}

func TestDetectStyleMixing_NegativeConsistentPlain(t *testing.T) {
	text := "これはペンだ。それもノートである。"
	m := DetectStyleMixing(text)
	if m.Mixed() {
		t.Fatalf("m = %+v, want Mixed() = false (consistent 常体)", m)
	}
}
