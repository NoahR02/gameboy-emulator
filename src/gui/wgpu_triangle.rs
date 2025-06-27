use std::mem::size_of;
use craft::renderer::vello::VelloRenderer;
use glam::{Mat4, Vec3};
use wgpu::{Device, Queue};
use wgpu::util::DeviceExt;
use crate::{GameBoy, GAMEBOY_SCREEN_HEIGHT, GAMEBOY_SCREEN_WIDTH};

pub struct Texture {
    pub texture_bind_group_layout: wgpu::BindGroupLayout,
    pub texture_bind_group: wgpu::BindGroup,
    pub texture: wgpu::Texture,
    pub width: u32,
    pub height: u32,
}

impl Texture {
    pub fn new(device: &Device, width: u32, height: u32) -> Self {
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("Red Texture"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8UnormSrgb,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        
        println!("{:?} {:?}", width, height);

        let texture_view = texture.create_view(&Default::default());
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("Texture Sampler"),
            ..Default::default()
        });

        let texture_bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Texture Bind Group Layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });

        let texture_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            layout: &texture_bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&texture_view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::Sampler(&sampler),
                },
            ],
            label: Some("Texture Bind Group"),
        });

        Self {
            texture_bind_group_layout,
            texture_bind_group,
            texture,
            width,
            height,
        }
    }

    pub fn write(&self, queue: &Queue, data: &[u8]) {
        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &self.texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            &data,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(4 * self.width),
                rows_per_image: Some(self.height),
            },
            wgpu::Extent3d { width: self.width, height: self.height, depth_or_array_layers: 1 },
        );

    }
}

pub struct RenderData {
    pub pipeline: wgpu::RenderPipeline,
    pub transform_bind_group_layout: wgpu::BindGroupLayout,
    pub texture: Texture,
}

impl RenderData {
    pub(crate) fn new(renderer: &VelloRenderer) -> Self {
        let shader = renderer.device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Textured Quad Shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()),
        });

        let transform_bind_group_layout = renderer.device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Transform Bind Group Layout"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });

        let texture = Texture::new(&renderer.device, GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT);

        let pipeline_layout = renderer.device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Textured Quad Pipeline Layout"),
            bind_group_layouts: &[&transform_bind_group_layout, &texture.texture_bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = renderer.device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Textured Quad Pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_main"),
                buffers: &[Vertex::desc()],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_main"),
                compilation_options: Default::default(),
                targets: &[Some(renderer.render_surface.surface_config.format.into())],
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });



        Self {
            pipeline,
            transform_bind_group_layout,
            texture,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct Vertex {
    position: [f32; 3],
    uv: [f32; 2],
}

impl Vertex {
    pub const fn desc() -> wgpu::VertexBufferLayout<'static> {
        wgpu::VertexBufferLayout {
            array_stride: size_of::<Vertex>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &[
                wgpu::VertexAttribute {
                    offset: 0,
                    shader_location: 0,
                    format: wgpu::VertexFormat::Float32x3,
                },
                wgpu::VertexAttribute {
                    offset: size_of::<[f32; 3]>() as wgpu::BufferAddress,
                    shader_location: 1,
                    format: wgpu::VertexFormat::Float32x2,
                },
            ],
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct TransformUniform {
    matrix: [[f32; 4]; 4],
}

pub(crate) fn render(renderer: &mut VelloRenderer, gb_state: &mut GameBoy, pos_x: f32, pos_y: f32, size_width: f32, size_height: f32, render_data: &RenderData) {
    if !renderer.render_into_texture {
        return;
    }

    let vertices = [
        Vertex { position: [0.0, 0.0, 0.0], uv: [0.0, 0.0] },
        Vertex { position: [0.0, 1.0, 0.0], uv: [0.0, 1.0] },
        Vertex { position: [1.0, 0.0, 0.0], uv: [1.0, 0.0] },
        Vertex { position: [1.0, 1.0, 0.0], uv: [1.0, 1.0] },
    ];

    let indices = [0u16, 1, 2, 2, 1, 3];

    let vertex_buffer = renderer.device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Vertex Buffer"),
        contents: bytemuck::cast_slice(&vertices),
        usage: wgpu::BufferUsages::VERTEX,
    });

    let index_buffer = renderer.device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Index Buffer"),
        contents: bytemuck::cast_slice(&indices),
        usage: wgpu::BufferUsages::INDEX,
    });

    let ortho = Mat4::orthographic_rh_gl(0.0, renderer.render_surface.width() as f32, renderer.render_surface.height() as f32, 0.0, -1.0, 1.0);
    let model = Mat4::from_translation(Vec3::new(pos_x, pos_y, 0.0)) * Mat4::from_scale(Vec3::new(size_width, size_height, 1.0));
    let mvp = ortho * model;

    let transform_data = TransformUniform { matrix: mvp.to_cols_array_2d() };
    let transform_buffer = renderer.device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Transform Buffer"),
        contents: bytemuck::bytes_of(&transform_data),
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
    });

    let transform_bind_group = renderer.device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &render_data.transform_bind_group_layout,
        entries: &[wgpu::BindGroupEntry {
            binding: 0,
            resource: transform_buffer.as_entire_binding(),
        }],
        label: Some("Transform Bind Group"),
    });

    render_data.texture.write(&renderer.queue, &gb_state.ppu.screen.data.as_slice());

    let surface_texture = renderer.render_surface.get_swapchain_surface_texture(&renderer.device, renderer.render_surface.width(), renderer.render_surface.height());
    let view = surface_texture.texture.create_view(&Default::default());

    let mut encoder = renderer.device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("Render Encoder"),
    });

    renderer.texture_blitter.copy(&renderer.device, &mut encoder, &renderer.render_surface.surface_view, &view);

    {
        let mut rpass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Render Pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: &view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
        });

        rpass.set_pipeline(&render_data.pipeline);
        rpass.set_bind_group(0, &transform_bind_group, &[]);
        rpass.set_bind_group(1, &render_data.texture.texture_bind_group, &[]);
        rpass.set_vertex_buffer(0, vertex_buffer.slice(..));
        rpass.set_index_buffer(index_buffer.slice(..), wgpu::IndexFormat::Uint16);
        rpass.draw_indexed(0..6, 0, 0..1);
    }

    renderer.queue.submit(Some(encoder.finish()));
    surface_texture.present();
}