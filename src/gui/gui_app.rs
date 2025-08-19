use craft::style::Unit;
use craft::components::Context;
use craft::elements::Canvas;
use craft::{
    components::{Component, ComponentSpecification},
    elements::{Container, ElementStyles},
    style::{AlignItems, Display, FlexDirection, JustifyContent},
};

#[derive(Default)]
pub struct GameboyApp {
}

impl Component for GameboyApp {
    type GlobalState = ();
    type Props = ();
    type Message = ();

    fn view(context: &mut Context<Self>) -> ComponentSpecification {
        let window_size = context.window().window_size();

        Container::new()
            .display(Display::Flex)
            .flex_direction(FlexDirection::Column)
            .justify_content(JustifyContent::Center)
            .align_items(AlignItems::Center)
            .width("100%")
            .height("100%")
            .push(Canvas::new().width(Unit::Px(window_size.width)).height(Unit::Px(window_size.height)).min_width("300px").min_height("300px"))
            .component()
    }
}