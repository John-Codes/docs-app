from app.chat.answer_guard import NO_ANSWER, guard_answer


def test_an_uncited_answer_is_replaced():
    answer, show_sources = guard_answer(
        "Why did the pump cross the road? It wanted to reach the other side.", 1
    )
    assert answer == NO_ANSWER
    assert show_sources is False


def test_a_cited_answer_is_kept():
    text = "Check the fluid before each shift [1]."
    answer, show_sources = guard_answer(text, 1)
    assert answer == text
    assert show_sources is True


def test_an_out_of_range_citation_is_not_a_citation():
    answer, show_sources = guard_answer("Check the fluid before each shift [3].", 2)
    assert answer == NO_ANSWER
    assert show_sources is False


def test_a_refusal_keeps_its_explanation_without_sources():
    text = "The documents don't cover that. The excerpt mentions only fluid checks."
    answer, show_sources = guard_answer(text, 1)
    assert answer == text
    assert show_sources is False


def test_an_empty_answer_becomes_the_refusal():
    answer, show_sources = guard_answer("   ", 1)
    assert answer == NO_ANSWER
    assert show_sources is False
